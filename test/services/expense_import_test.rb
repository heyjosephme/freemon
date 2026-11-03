# frozen_string_literal: true

require "test_helper"

# Reading files, line numbers, dates, amounts and saving are shared with
# RevenueImport (see CsvImport) and tested there.
class ExpenseImportTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "reads every column" do
    import = ExpenseImport.new(<<~CSV)
      日付,内容,金額,カテゴリ,按分率,インボイス,購入方法
      2030-07-01,MacBook Pro,"¥298,000",備品,８０％,○,オンライン
    CSV

    assert_not import.errors?
    assert_equal({ date: Date.new(2030, 7, 1), description: "MacBook Pro", amount: 298_000, category: "equipment",
                   business_ratio: 80, invoice_eligible: true, purchase_channel: "online" },
                 import.rows.first.attributes)
  end

  test "購入方法 takes オンライン or 店頭, and defaults to 店頭・対面" do
    { "オンライン" => "online", "ｵﾝﾗｲﾝ" => "online", "online" => "online", "o" => "online",
      "店頭" => "in_person", "対面" => "in_person", "" => "in_person" }.each do |cell, expected|
      import = ExpenseImport.new("日付,内容,金額,購入方法\n2030-08-15,X,1000,#{cell}\n")
      assert_equal expected, import.rows.first[:purchase_channel], cell
    end
    assert_equal "in_person", ExpenseImport.new("日付,内容,金額\n2030-08-15,X,1000\n").rows.first[:purchase_channel]
    assert ExpenseImport.new("日付,内容,金額,購入方法\n2030-08-15,X,1000,郵送\n").errors?
  end

  test "blank optional cells mean その他 and 100%, and leave インボイス unset" do
    import = ExpenseImport.new("日付,内容,金額,カテゴリ,按分率,インボイス\n2030-08-15,技術書,3520,,,\n")
    assert_equal [ "other", 100, nil ], import.rows.first.attributes.values_at(:category, :business_ratio, :invoice_eligible)
  end

  test "without an インボイス column the status is left unset" do
    import = ExpenseImport.new("日付,内容,金額\n2030-08-15,技術書,3520\n")
    assert_nil import.rows.first[:invoice_eligible]
  end

  test "a category can be named by its key, its form label, or any part of the label" do
    { "equipment" => "equipment", "備品・器具 (Equipment)" => "equipment", "器具" => "equipment",
      "ｿﾌﾄｳｪｱ" => "software", "Books" => "books", "通信費" => "communication" }.each do |name, key|
      import = ExpenseImport.new("日付,内容,金額,カテゴリ\n2030-08-15,X,1000,#{name}\n")
      assert_equal key, import.rows.first[:category], name
    end
  end

  test "an unknown category lists the valid ones" do
    row = ExpenseImport.new("日付,内容,金額,カテゴリ\n2030-08-15,ランチ,1000,食費\n").rows.first

    assert_equal :error, row.status
    assert_match "カテゴリが不明です", row.message
    assert_match "備品・器具", row.message
  end

  test "按分率 must be a whole percentage from 1 to 100" do
    rows = ExpenseImport.new("日付,内容,金額,按分率\n#{%w[0 120 0.8 半分].map { |ratio| "2030-08-15,X,1000,#{ratio}\n" }.join}").rows
    assert rows.all? { |row| row.status == :error && row.message.include?("按分率は1〜100") }
  end

  test "インボイス takes y or n, and null or blank for unset" do
    { "y" => true, "Y" => true, "ｙ" => true, "n" => false, "N" => false, "ｎ" => false,
      "○" => true, "yes" => true, "あり" => true, "×" => false, "no" => false }.each do |cell, expected|
      assert_equal expected, invoice_status(cell), cell
    end
    [ "null", "未設定", "-" ].each { |cell| assert_nil invoice_status(cell), cell }
    assert ExpenseImport.new("日付,内容,金額,インボイス\n2030-08-15,X,1000,たぶん\n").errors?
  end

  test "saving creates the expense, and re-running the file skips it" do
    csv = "日付,内容,金額,カテゴリ,按分率\n2030-07-01,MacBook Pro,298000,備品,80\n"
    assert_equal 1, ExpenseImport.new(csv).save!

    expense = @fiscal_year.expenses.sole
    assert_equal [ "equipment", 80, 238_400, nil ],
                 [ expense.category, expense.business_ratio, expense.deductible_amount, expense.invoice_eligible ]
    assert_equal [ :duplicate ], ExpenseImport.new(csv).rows.map(&:status)
  end

  test "内容 is required, the optional columns are not" do
    import = ExpenseImport.new("日付,金額\n2030-07-01,1000\n")

    assert_match "内容", import.problems.first
    assert_no_match "カテゴリ", import.problems.first
  end

  private

  def invoice_status(cell)
    import = ExpenseImport.new("日付,内容,金額,インボイス\n2030-08-15,X,1000,#{cell}\n")
    assert_not import.errors?, cell
    import.rows.first[:invoice_eligible]
  end
end
