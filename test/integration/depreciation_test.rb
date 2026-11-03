# frozen_string_literal: true

require "test_helper"

class DepreciationTest < ActionDispatch::IntegrationTest
  setup do
    load Rails.root.join("db/seeds.rb") # the chart of accounts
    @bought = FiscalYear.create!(year: 2030)
    @bought.revenues.create!(client_name: "テスト社", amount: 1_100_000, date: Date.new(2030, 6, 1))
    @bought.expenses.create!(description: "MacBook Pro", amount: 500_000, category: :equipment, kind: :asset,
                             accounting_method: :normal_depreciation, useful_life: 4, business_ratio: 80, date: Date.new(2030, 7, 15))
    @following = FiscalYear.create!(year: 2031)
    @following.expenses.create!(description: "モニター", amount: 150_000, category: :equipment, kind: :asset,
                                accounting_method: :small_asset_special, date: Date.new(2031, 3, 1))
  end

  test "the 減価償却費の計算 lists last year's asset and this year's 少額特例 purchase" do
    get depreciation_fiscal_year_url(@following)

    rows = css_select("tbody tr").map { |row| row.css("td").map { |cell| cell.text.strip } }
    assert_equal [ "MacBook Pro", "2030年7月", "¥500,000", "定額法", "4年", "0.250", "12/12", "¥125,000", "80%", "¥100,000", "¥312,500" ],
                 rows.first
    assert_equal [ "モニター", "2031年3月", "¥150,000", "少額特例", "—", "—", "—", "¥150,000", "100%", "¥150,000", "¥0" ], rows.second
    assert_equal [ "合計", "¥275,000", "", "¥250,000", "¥312,500" ], css_select("tfoot td").map { |cell| cell.text.strip }
  end

  test "the 損益計算書 shows the year's 減価償却費" do
    get income_statement_fiscal_year_url(@following)

    assert_match "511 減価償却費", response.body
    assert_match "¥250,000", response.body
  end

  test "the 貸借対照表 carries the asset into the next year and still balances" do
    get balance_sheet_fiscal_year_url(@following)

    assert_match "150 工具器具備品", response.body
    assert_match "¥312,500", response.body   # 500,000 − 62,500 − 125,000
    assert_match "¥1,037,500", response.body # 元入金: 2030's income 1,050,000 less 事業主貸 12,500
    assert_match "資産 = 負債 + 資本 ✓", response.body
  end

  test "a year without assets says so" do
    get depreciation_fiscal_year_url(FiscalYear.create!(year: 2029))
    assert_match "この年に償却する資産はありません", response.body
  end
end
