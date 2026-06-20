# frozen_string_literal: true

require "test_helper"

class FiscalYearsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
    @fiscal_year.revenues.create!(client_name: "テスト社", amount: 5_000_000, date: Date.new(2099, 6, 1))
    @fiscal_year.expenses.create!(description: "PC", amount: 1_000_000, category: :equipment, business_ratio: 100, date: Date.new(2099, 6, 1))
  end

  test "dashboard renders the tax-reserve banner and analysis links" do
    get fiscal_year_url(@fiscal_year)
    assert_response :success
    assert_match "納税準備の目安", @response.body
    assert_match "節税シミュレーション", @response.body
  end

  test "cashflow page renders the SVG chart and breakdowns" do
    get cashflow_fiscal_year_url(@fiscal_year)
    assert_response :success
    assert_match "月次キャッシュフロー", @response.body
    assert_match "<svg", @response.body
    assert_match "取引先別", @response.body
  end

  test "tax-reserve page renders the breakdown" do
    get tax_reserve_fiscal_year_url(@fiscal_year)
    assert_response :success
    assert_match "納税準備の目安", @response.body
    assert_match "国民健康保険", @response.body
  end

  test "tax-saving page renders the marginal rate and instruments" do
    get tax_saving_fiscal_year_url(@fiscal_year)
    assert_response :success
    assert_match "限界税率", @response.body
    assert_match "小規模企業共済", @response.body
  end
end
