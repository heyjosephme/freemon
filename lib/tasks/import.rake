# frozen_string_literal: true

# Shared by the CSV import tasks below: previews every row, then saves with
# COMMIT=1, or aborts without saving anything when a row has an error.
run_csv_import = lambda do |import_class, task:, noun:, example:|
  $stdout.sync = true # keeps the report ahead of abort's stderr message when piped
  path = ENV["FILE"].presence or abort "使い方: bin/rails #{task} FILE=#{example} [COMMIT=1]"
  abort "ファイルが見つかりません: #{path}" unless File.file?(path)

  import = import_class.from_file(path)
  yen = ->(amount) { "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}" }
  labels = { new: "新規  ", duplicate: "重複  ", error: "エラー" } # equal display widths

  puts "#{path}: #{import.rows.size}行"
  import.rows.each do |row|
    detail = if row.status == :error
      row.message
    else
      "#{import.describe(row)}#{" ※登録済みのためスキップ" if row.status == :duplicate}"
    end
    puts format("  %s %3d行目  %s", labels[row.status], row.line, detail)
  end
  import.problems.each { |problem| puts "  エラー: #{problem}" }
  import.warnings.each { |warning| puts "  注意: #{warning}" }

  import.rows.reject { |row| row.status == :error }.group_by { |row| row.fiscal_year.year }.sort.each do |year, rows|
    fresh = rows.select { |row| row.status == :new }
    skipped = rows.size - fresh.size
    total = "#{yen.(fresh.sum { |row| row[:amount] })}#{import.total_note(fresh) if fresh.any?}"
    puts "#{year}年: 新規#{fresh.size}件 #{total}#{"、重複スキップ#{skipped}件" if skipped.positive?}"
  end

  if import.errors?
    abort "エラーがあるため何も保存していません。CSVを直して再実行してください。"
  elsif ENV["COMMIT"] == "1"
    begin
      puts "#{import.save!}件の#{noun}を保存しました。"
    rescue CsvImport::Invalid => e
      abort "#{e.message}。何も保存していません。"
    end
  else
    puts "ドライランです（まだ保存していません）。COMMIT=1 を付けて再実行すると保存します。"
  end
end

namespace :revenues do
  desc "Import revenues from a CSV (日付,取引先,金額); dry run unless COMMIT=1. Usage: bin/rails revenues:import FILE=sales.csv [COMMIT=1]"
  task import: :environment do
    run_csv_import.(RevenueImport, task: "revenues:import", noun: "売上", example: "sales.csv")
  end
end

namespace :expenses do
  desc "Import expenses from a CSV (日付,内容,金額 + optional カテゴリ,按分率,インボイス); dry run unless COMMIT=1. Usage: bin/rails expenses:import FILE=expenses.csv [COMMIT=1]"
  task import: :environment do
    run_csv_import.(ExpenseImport, task: "expenses:import", noun: "経費", example: "expenses.csv")
  end
end
