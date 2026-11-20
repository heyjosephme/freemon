# frozen_string_literal: true

require "test_helper"

class DashboardLayoutTest < ActionDispatch::IntegrationTest
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099)
  end

  test "sections follow how often they're used" do
    get fiscal_year_url(@fiscal_year)

    headings = [ "経費 (Expenses)", "事業収入 (Revenue)", "給与所得 (Salary Income)", "所得控除 (Deductions)",
                 "帳簿・レポート", "分析・節税" ]
    positions = headings.map { |heading| response.body.index(heading) }
    assert positions.all?, "every section is on the page"
    assert_equal positions.sort, positions
  end

  test "this month's spending shows for the current year only" do
    previous = FiscalYear.create!(year: 2098)
    travel_to Date.new(2099, 3, 10) do
      @fiscal_year.expenses.create!(description: "今月", amount: 1_000, category: :other, date: Date.new(2099, 3, 1))
      @fiscal_year.expenses.create!(description: "先月", amount: 5_000, category: :other, business_ratio: 50,
                                    date: Date.new(2099, 2, 1))

      get fiscal_year_url(@fiscal_year)
      assert_select "#expense-totals", text: /今月\s*¥1,000/
      assert_select "#expense-totals", text: /年間\s*¥3,500/ # 1,000 + 5,000 × 50%

      get fiscal_year_url(previous)
      assert_select "#expense-totals", text: /今月/, count: 0
    end
  end

  test "net business income is revenue less expenses after 按分, before the blue deduction" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 1, 31))
    @fiscal_year.expenses.create!(description: "家賃", amount: 40_000, category: :office, business_ratio: 50,
                                  date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit", text: /¥80,000/ # 100,000 − 40,000 × 50%; no 65万円 deduction
    assert_select "#business-profit", text: /青色申告特別控除前/
    assert response.body.index("事業収入 (Revenue)") < response.body.index("事業利益 (Net business income)")
  end

  test "a loss shows as a negative figure, and 白色 has no blue deduction to mention" do
    @fiscal_year.update!(filing_type: :white)
    @fiscal_year.expenses.create!(description: "機材", amount: 30_000, category: :other, date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit .text-negative", text: "-¥30,000"
    assert_select "#business-profit", text: /青色申告特別控除前/, count: 0
  end

  test "without a target the card links to the settings" do
    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", count: 0
    assert_select "#business-profit a[href=?]", edit_fiscal_year_path(@fiscal_year), text: /目標を設定/
  end

  test "a target shows the progress meter and what is left" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 100_000, date: Date.new(2099, 1, 31))
    @fiscal_year.expenses.create!(description: "家賃", amount: 40_000, category: :office, business_ratio: 50,
                                  date: Date.new(2099, 1, 5))

    patch fiscal_year_url(@fiscal_year), params: { fiscal_year: { business_profit_target: 300_000 } }
    assert_redirected_to fiscal_year_url(@fiscal_year)
    follow_redirect!

    # 利益 80,000 ÷ 目標 300,000 = 26.6…% → 26%; 残り 220,000
    assert_select "#business-profit-target", text: /目標 \(Target\)\s*¥300,000/
    assert_select "#business-profit-target [role=meter][aria-valuenow='26'] div[style='width: 26%']"
    assert_select "#business-profit-target", text: /目標まであと \(To go\)\s*¥220,000/
  end

  test "past the target the meter stays full and the surplus is in the text" do
    @fiscal_year.update!(business_profit_target: 50_000)
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 80_000, date: Date.new(2099, 1, 31))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", text: /160%/ # 80,000 ÷ 50,000
    assert_select "#business-profit-target [role=meter] div[style='width: 100%']"
    assert_select "#business-profit-target", text: /目標達成.*\+¥30,000/m
  end

  test "a loss leaves the meter empty and adds the loss to what is left" do
    @fiscal_year.update!(business_profit_target: 50_000)
    @fiscal_year.expenses.create!(description: "機材", amount: 30_000, category: :other, date: Date.new(2099, 1, 5))

    get fiscal_year_url(@fiscal_year)
    assert_select "#business-profit-target", text: /0%/
    assert_select "#business-profit-target [role=meter] div", count: 0
    assert_select "#business-profit-target", text: /¥80,000/ # 50,000 + 30,000
  end

  test "the target must be a positive whole number of yen, or blank" do
    assert_not FiscalYear.new(year: 2098, business_profit_target: 0).valid?
    assert_not FiscalYear.new(year: 2098, business_profit_target: -1).valid?

    @fiscal_year.update!(business_profit_target: 50_000)
    patch fiscal_year_url(@fiscal_year), params: { fiscal_year: { business_profit_target: "" } }
    assert_nil @fiscal_year.reload.business_profit_target
  end

  test "the dashboard lists the latest five expenses and three revenues" do
    1.upto(6) do |day|
      @fiscal_year.expenses.create!(description: "経費#{day}", amount: day, category: :other, date: Date.new(2099, 1, day))
      @fiscal_year.revenues.create!(client_name: "取引先#{day}", amount: day, date: Date.new(2099, 1, day))
    end
    get fiscal_year_url(@fiscal_year)

    assert_select "#recent-expenses a", count: 5
    assert_select "#recent-expenses a", text: /経費6/
    assert_select "#recent-expenses a", text: /経費1/, count: 0
    assert_select "#recent-revenues li", count: 3
    assert_select "#recent-revenues a[href=?]", edit_fiscal_year_revenue_path(@fiscal_year, @fiscal_year.revenues.find_by!(client_name: "取引先6"), return_to: "dashboard")
  end

  test "an unexpected return_to can't redirect elsewhere" do
    post fiscal_year_expenses_url(@fiscal_year), params: {
      return_to: "https://example.com", expense: { description: "A", amount: 1000, category: "other", date: "2099-01-01" }
    }
    assert_redirected_to fiscal_year_expenses_url(@fiscal_year)
  end
end
