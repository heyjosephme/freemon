# frozen_string_literal: true

require "test_helper"

class FixedAssetTaxTest < ActionDispatch::IntegrationTest
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "the 償却資産税 page values each declared asset and says when the total is under the 免税点" do
    asset("カメラ", 350_000, :small_asset_special, useful_life: 5)

    get fixed_asset_tax_fiscal_year_url(@fiscal_year)

    assert_select "h1", text: "2031年度 償却資産税 (Fixed asset tax)"
    assert_equal [ "カメラ", "2030年7月", "¥350,000", "少額特例", "5年", "0.369", "¥285,250" ],
                 css_select("tbody tr td").map { |cell| cell.text.strip }
    assert_match "課税標準額が免税点 ¥1,800,000 未満なので、課税されない見込みです。", response.body
    assert_match "2031年1月31日までに", response.body
  end

  test "an asset without a useful life is flagged with a link to its form" do
    monitor = asset("モニター", 150_000, :small_asset_special)

    get fixed_asset_tax_fiscal_year_url(@fiscal_year)

    assert_match "耐用年数が未入力の資産があります。", response.body
    assert_select "a[href=?]", edit_fiscal_year_expense_path(@fiscal_year, monitor), text: "モニター（¥150,000）"
  end

  test "a year with nothing to declare says so" do
    get fixed_asset_tax_fiscal_year_url(@fiscal_year)
    assert_match "申告の対象になる資産はありません", response.body
  end

  test "the 減価償却 page shows how much of the 特例's ¥3,000,000 is used" do
    asset("カメラ", 350_000, :small_asset_special)
    asset("モニター", 150_000, :small_asset_special)

    get depreciation_fiscal_year_url(@fiscal_year)

    assert_match "少額減価償却資産の特例 (Special measure for small assets)", response.body
    assert_match "¥500,000", response.body
    assert_match "¥2,500,000", response.body
  end

  test "the dashboard links to the page" do
    get fiscal_year_url(@fiscal_year)
    assert_select "a[href=?]", fixed_asset_tax_fiscal_year_path(@fiscal_year), text: "償却資産税"
  end

  private

  def asset(description, amount, method, **attributes)
    @fiscal_year.expenses.create!(description: description, amount: amount, category: :equipment, kind: :asset,
                                  accounting_method: method, date: Date.new(2030, 7, 1), **attributes)
  end
end
