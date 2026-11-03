# frozen_string_literal: true

require "csv"

# Base for bulk imports from a hand-made CSV with a header row. Subclasses set
# MODEL, IDENTITY (the attributes that make two rows the same) and COLUMNS
# (accepted header names, and which columns are required), and turn each row's
# raw values into attributes in #attributes_for.
#
# Every row is parsed and checked up front. #save! then creates the new rows
# in one transaction, and only when no row has an error. Each row goes to the
# fiscal year of its date, and rows identical to an existing record are
# skipped, so re-running a file is safe.
class CsvImport
  Invalid = Class.new(StandardError)

  Row = Data.define(:line, :attributes, :fiscal_year, :status, :message) do
    def [](attribute) = attributes[attribute]
  end

  DATE_FORMATS = [
    %r{\A(\d{4})[-/.](\d{1,2})[-/.](\d{1,2})\z}, # 2026-07-31, 2026/7/31
    /\A(\d{4})年(\d{1,2})月(\d{1,2})日\z/          # 2026年7月31日
  ].freeze

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

    ActiveRecord::Base.transaction do
      new_rows.each do |row|
        row.fiscal_year.public_send(association).create!(row.attributes)
      rescue ActiveRecord::RecordInvalid => e
        # Rows checked one by one can still clash together, e.g. over the 特例's yearly cap.
        raise Invalid, "#{row.line}行目: #{model_error_messages(e.record).join("、")}"
      end
    end
    new_rows.size
  end

  # One line describing a valid row, for the CLI preview.
  def describe(row) = raise(NotImplementedError)

  # Optional note after a year's total in the CLI summary.
  def total_note(rows) = nil

  private

  def association = self.class::MODEL.model_name.plural

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

  # Each column's position in the header row; nil for an absent optional column.
  def column_indexes(headers)
    normalized = headers.map { |header| normalize(header).downcase }
    indexes = self.class::COLUMNS.transform_values { |column| normalized.index { |header| column[:names].include?(header) } }
    missing = indexes.select { |key, index| index.nil? && self.class::COLUMNS[key][:required] }.keys
    return indexes if missing.empty?

    required = self.class::COLUMNS.values.select { |column| column[:required] }.map { |column| column[:names].first }
    @problems << "見出し行に #{missing.map { |key| self.class::COLUMNS[key][:names].first }.join("・")} の列がありません（必要な列: #{required.join(",")}）"
    nil
  end

  # Values are strings ("" for a blank cell), or nil when the column is absent.
  def build_row(line, record, columns)
    values = columns.transform_values { |index| record[index].to_s if index }
    errors = []
    attributes = attributes_for(values, errors)
    date = attributes[:date]
    fiscal_year = fiscal_years[date.year] if date
    errors << "#{date.year}年の年度がありません（先に作成してください）" if date && !fiscal_year
    if errors.empty?
      record = self.class::MODEL.new(attributes.merge(fiscal_year: fiscal_year))
      if record.valid?
        # Keep what the model settled on (e.g. a suggested accounting method), so the preview shows what gets saved.
        attributes = attributes.to_h { |key, _value| [ key, record.public_send(key) ] }
      else
        errors.concat(model_error_messages(record))
      end
    end

    status = if errors.any?
      :error
    elsif fiscal_year.public_send(association).exists?(attributes.slice(*self.class::IDENTITY))
      :duplicate
    else
      :new
    end
    Row.new(line: line, attributes: attributes, fiscal_year: fiscal_year, status: status, message: errors.join("、").presence)
  end

  # Backstop for model validations the parser doesn't know about.
  # Messages the model writes as whole sentences read better without the attribute name.
  def model_error_messages(record)
    record.errors.map { |error| error.type.is_a?(String) ? error.message : error.full_message }
  end

  def date_value(text, errors)
    normalized = normalize(text)
    DATE_FORMATS.each do |format|
      year, month, day = format.match(normalized)&.captures&.map(&:to_i)
      return Date.new(year, month, day) if year && Date.valid_date?(year, month, day)
    end
    errors << "日付が読めません: #{text.inspect}"
    nil
  end

  # Tax-included yen as a positive integer: 550000, "¥550,000", ２２０，０００円, or
  # Excel's Shift_JIS "\550,000" (its yen sign decodes as a backslash).
  def amount_value(text, errors)
    digits = normalize(text).gsub(/[¥\\,円[:space:]]/, "")
    return digits.to_i if digits.match?(/\A\d+\z/) && digits.to_i.positive?

    errors << "金額が読めません: #{text.inspect}"
    nil
  end

  def text_value(text, label, errors)
    value = text.to_s.gsub(/\A[[:space:]]+|[[:space:]]+\z/, "")
    errors << "#{label}が空です" if value.empty?
    value
  end

  # NFKC turns full-width digits, letters, commas, yen signs and spaces into ASCII.
  def normalize(text) = text.to_s.unicode_normalize(:nfkc).strip

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"

  def fiscal_years
    @fiscal_years ||= FiscalYear.all.index_by(&:year)
  end

  def warn_about_repeated_rows
    new_rows.group_by { |row| row.attributes.slice(*self.class::IDENTITY) }.each_value do |repeats|
      next if repeats.one?

      @warnings << "同じ内容の行があります: #{repeats.map { |row| "#{row.line}行目" }.join("・")}（すべて登録されます）"
    end
  end
end
