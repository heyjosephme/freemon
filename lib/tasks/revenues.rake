# frozen_string_literal: true

namespace :revenues do
  desc "Import revenues from a CSV (日付,取引先,金額); dry run unless COMMIT=1. Usage: bin/rails revenues:import FILE=sales.csv [COMMIT=1]"
  task import: :environment do
    $stdout.sync = true # keeps the report ahead of abort's stderr message when piped
    path = ENV["FILE"].presence or abort "使い方: bin/rails revenues:import FILE=sales.csv [COMMIT=1]"
    abort "ファイルが見つかりません: #{path}" unless File.file?(path)

    import = RevenueImport.from_file(path)
    yen = ->(amount) { "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}" }
    labels = { new: "新規  ", duplicate: "重複  ", error: "エラー" } # equal display widths

    puts "#{path}: #{import.rows.size}行"
    import.rows.each do |row|
      detail = if row.status == :error
        row.message
      else
        format("%s  %12s  %s%s", row.date, yen.(row.amount), row.client_name,
               row.status == :duplicate ? "（登録済みのためスキップ）" : "")
      end
      puts format("  %s %3d行目  %s", labels[row.status], row.line, detail)
    end
    import.problems.each { |problem| puts "  エラー: #{problem}" }
    import.warnings.each { |warning| puts "  注意: #{warning}" }

    import.rows.reject { |row| row.status == :error }.group_by { |row| row.fiscal_year.year }.sort.each do |year, rows|
      fresh = rows.select { |row| row.status == :new }
      skipped = rows.size - fresh.size
      puts "#{year}年: 新規#{fresh.size}件 #{yen.(fresh.sum(&:amount))}#{"、重複スキップ#{skipped}件" if skipped.positive?}"
    end

    if import.errors?
      abort "エラーがあるため何も保存していません。CSVを直して再実行してください。"
    elsif ENV["COMMIT"] == "1"
      puts "#{import.save!}件の売上を保存しました。"
    else
      puts "ドライランです（まだ保存していません）。COMMIT=1 を付けて再実行すると保存します。"
    end
  end
end
