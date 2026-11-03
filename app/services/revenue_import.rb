# frozen_string_literal: true

require "csv"

# Bulk-imports revenues from a hand-made CSV with a header row:
#
#   日付,取引先,金額
#   2026-07-31,株式会社テックコープ,"¥550,000"
#
# Every row is parsed and checked up front. #save! then creates the new rows
# in one transaction, and only when no row has an error. Each row goes to the
# fiscal year of its date, and rows identical to an existing revenue (same
# date, client and amount) are skipped, so re-running a file is safe.
class RevenueImport
  Invalid = Class.new(StandardError)

  # Accepted header names per column, compared after NFKC normalization and downcasing.
  HEADERS = {
    date: [ "日付", "date" ],
    client_name: [ "取引先", "取引先名", "client", "client_name" ],
    amount: [ "金額", "金額(税込)", "amount" ]
  }.freeze

  DATE_FORMATS = [
    %r{\A(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\z}, # 2026-07-31, 2026/7/31
    /\A(\d{4})年(\d{1,2})月(\d{1,2})日\z/          # 2026年7月31日
  ].freeze

  Row = Data.define(:line, :date, :client_name, :amount, :fiscal_year, :status, :message)

  attr_reader :rows, :problems, :warnings

  # Reads UTF-8 (with or without a BOM) or Shift_JIS, which Excel writes on Japanese Windows.
  def self.from_file(path)
    bytes = File.binread(path).delete_prefix("\xEF\xBB\xBF".b)
    utf8 = bytes.dup.force_encoding(Encoding::UTF_8)
    new(utf8.valid_encoding? ? utf8 : bytes.encode(Encoding::UTF_8, Encoding::Windows_31J))
  rescue EncodingError
    new("", problem: "文字コードを判別できません（UTF-8 か Shift_JIS で保存してください）")
  end

  def initialize(csv_text, problem: nil)
    @problems = Array(problem)
    @warnings = []
    @rows = problem ? [] : parse(csv_text)
    warn_about_repeated_rows
  end

  def errors?
    problems.any? || rows.any? { |row| row.status == :error }
  end

  def new_rows = rows.select { |row| row.status == :new }

  # Creates the new rows in one transaction and returns how many were saved.
  def save!
    raise Invalid, "エラーがあるため保存できません" if errors?

    Revenue.transaction do
      new_rows.each do |row|
        row.fiscal_year.revenues.create!(date: row.date, client_name: row.client_name, amount: row.amount)
      end
    end
    new_rows.size
  end

  private

  def parse(text)
    csv = CSV.new(text, headers: true, return_headers: true)
    columns = nil
    rows = []
    csv.each do |record|
      if record.header_row?
        columns = column_indexes(record.fields) or return []
      elsif record.fields.any?(&:present?)
        rows << build_row(csv.lineno, record, columns)
      end
    end
    @problems << "データ行がありません" if rows.empty?
    rows
  rescue CSV::MalformedCSVError => e
    @problems << "CSVの形式が正しくありません: #{e.message}"
    []
  end

  def column_indexes(headers)
    normalized = headers.map { |header| normalize(header).downcase }
    indexes = HEADERS.transform_values { |names| normalized.index { |header| names.include?(header) } }
    missing = indexes.select { |_column, index| index.nil? }.keys
    return indexes if missing.empty?

    @problems << "見出し行に #{missing.map { |column| HEADERS[column].first }.join("・")} の列がありません（必要な列: 日付,取引先,金額）"
    nil
  end

  def build_row(line, record, columns)
    date_text, client_text, amount_text = columns.values_at(:date, :client_name, :amount).map { |index| record[index] }
    date = parse_date(date_text)
    client_name = client_text.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    amount = parse_amount(amount_text)
    fiscal_year = fiscal_years[date.year] if date

    errors = []
    errors << "日付が読めません: #{date_text.to_s.inspect}" unless date
    errors << "取引先が空です" if client_name.empty?
    errors << "金額が読めません: #{amount_text.to_s.inspect}" unless amount
    errors << "#{date.year}年の年度がありません（先に作成してください）" if date && !fiscal_year
    errors.concat(model_errors(fiscal_year, date, client_name, amount)) if errors.empty?

    status = if errors.any?
      :error
    elsif fiscal_year.revenues.exists?(date: date, client_name: client_name, amount: amount)
      :duplicate
    else
      :new
    end
    Row.new(line: line, date: date, client_name: client_name, amount: amount, fiscal_year: fiscal_year,
            status: status, message: errors.join("、").presence)
  end

  def parse_date(text)
    normalized = normalize(text)
    DATE_FORMATS.each do |format|
      year, month, day = format.match(normalized)&.captures&.map(&:to_i)
      return Date.new(year, month, day) if year && Date.valid_date?(year, month, day)
    end
    nil
  end

  # Tax-included yen as a positive integer: 550000, "¥550,000", ２２０，０００円, or
  # Excel's Shift_JIS "\550,000" (its yen sign decodes as a backslash).
  def parse_amount(text)
    digits = normalize(text).gsub(/[¥\\,円[:space:]]/, "")
    digits.to_i if digits.match?(/\A\d+\z/) && digits.to_i.positive?
  end

  # Backstop for Revenue validations the parser doesn't know about.
  def model_errors(fiscal_year, date, client_name, amount)
    revenue = Revenue.new(fiscal_year: fiscal_year, date: date, client_name: client_name, amount: amount)
    revenue.valid? ? [] : revenue.errors.full_messages
  end

  # NFKC turns full-width digits, commas, yen signs and spaces into ASCII.
  def normalize(text) = text.to_s.unicode_normalize(:nfkc).strip

  def fiscal_years
    @fiscal_years ||= FiscalYear.all.index_by(&:year)
  end

  def warn_about_repeated_rows
    new_rows.group_by { |row| [ row.date, row.client_name, row.amount ] }.each_value do |repeats|
      next if repeats.one?

      @warnings << "同じ内容の行があります: #{repeats.map { |row| "#{row.line}行目" }.join("・")}（すべて登録されます）"
    end
  end
end
