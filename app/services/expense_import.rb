# frozen_string_literal: true

# Expenses from a CSV with the columns 日付,内容,金額 (tax-included), plus the
# optional カテゴリ, 按分率, インボイス and 購入方法:
#
#   日付,内容,金額,カテゴリ,按分率,インボイス,購入方法
#   2026-07-01,MacBook Pro,298000,備品,80%,y,オンライン
#   2026-08-15,技術書,3520,書籍,,,店頭
#
# Blank cells mean その他, 100% and 店頭・対面. インボイス is y (あり) or n (なし),
# with ○/× and yes/no also accepted; a blank cell, "null" or a missing column
# leaves it unset (nil), like a new expense in the form.
# See CsvImport for how files are read and saved.
class ExpenseImport < CsvImport
  MODEL = Expense
  IDENTITY = %i[date description amount].freeze
  COLUMNS = {
    date: { names: [ "日付", "date" ], required: true },
    description: { names: [ "内容", "摘要", "品目", "description" ], required: true },
    amount: { names: [ "金額", "金額(税込)", "amount" ], required: true },
    category: { names: [ "カテゴリ", "カテゴリー", "category" ] },
    business_ratio: { names: [ "按分率", "家事按分", "事業割合", "business_ratio" ] },
    invoice_eligible: { names: [ "インボイス", "インボイス対応", "invoice", "invoice_eligible" ] },
    purchase_channel: { names: [ "購入方法", "購入", "channel", "purchase_channel" ] }
  }.freeze

  # Every name a category answers to: its key, its full label as the form shows
  # it, and each part of that label, so 備品・器具 (Equipment) also matches
  # "備品・器具", "備品", "器具" and "equipment".
  CATEGORIES = Expense::CATEGORY_LABELS.each_with_object({}) do |(key, label), names|
    japanese, english = label.match(/\A(.+) \((.+)\)\z/).captures
    [ key, label, japanese, *japanese.split("・"), english, *english.split("/") ].each do |name|
      names[name.unicode_normalize(:nfkc).downcase] = key
    end
  end.freeze

  INVOICE_YES = %w[y yes ○ ◯ 〇 ✓ ✔ あり 有 対応 true 1].freeze
  INVOICE_NO = %w[n no × ✗ なし 無 非対応 false 0].freeze
  INVOICE_UNSET = [ "", "null", "nil", "未設定", "不明", "-", "ー" ].freeze

  CHANNELS = {
    "online" => %w[オンライン ネット online web o],
    "in_person" => %w[店頭 対面 店頭・対面 実店舗 in-person in_person offline i]
  }.flat_map { |key, names| names.map { |name| [ name, key ] } }.to_h.freeze

  def describe(row)
    details = [ Expense.category_name(row[:category]), "按分#{row[:business_ratio]}%" ]
    details << { true => "インボイスあり", false => "インボイスなし" }[row[:invoice_eligible]]
    details << "オンライン" if row[:purchase_channel] == "online"
    format("%s  %12s  %s（%s）", row[:date], yen(row[:amount]), row[:description], details.compact.join("、"))
  end

  # The deductible (家事按分後) total, rounded per row like Expense#deductible_amount.
  def total_note(rows)
    "（按分後 #{yen(rows.sum { |row| row[:amount] * row[:business_ratio] / 100 })}）"
  end

  private

  def attributes_for(values, errors)
    {
      date: date_value(values[:date], errors),
      description: text_value(values[:description], "内容", errors),
      amount: amount_value(values[:amount], errors),
      category: category_value(values[:category], errors),
      business_ratio: ratio_value(values[:business_ratio], errors),
      invoice_eligible: invoice_value(values[:invoice_eligible], errors),
      purchase_channel: channel_value(values[:purchase_channel], errors)
    }
  end

  def channel_value(text, errors)
    name = normalize(text).downcase
    return "in_person" if name.empty?

    CHANNELS.fetch(name) do
      errors << "購入方法は オンライン か 店頭 で入力してください: #{text.inspect}"
      nil
    end
  end

  def category_value(text, errors)
    name = normalize(text).downcase
    return "other" if name.empty?

    CATEGORIES.fetch(name) do
      errors << "カテゴリが不明です: #{text.inspect}（使える値: #{Expense::CATEGORY_LABELS.keys.map { |key| Expense.category_name(key) }.join("、")}）"
      nil
    end
  end

  def ratio_value(text, errors)
    ratio = normalize(text).delete("%").strip
    return 100 if ratio.empty?
    return ratio.to_i if ratio.match?(/\A\d+\z/) && ratio.to_i.between?(1, 100)

    errors << "按分率は1〜100で入力してください: #{text.inspect}"
    nil
  end

  # true, false, or nil when unset (text is nil when the column is absent).
  def invoice_value(text, errors)
    word = normalize(text).downcase
    return true if INVOICE_YES.include?(word)
    return false if INVOICE_NO.include?(word)
    return nil if INVOICE_UNSET.include?(word)

    errors << "インボイスは y（あり）・n（なし）か空欄（未設定）で入力してください: #{text.inspect}"
    nil
  end
end
