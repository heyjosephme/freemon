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

  test "the dashboard lists the latest five expenses and three revenues" do
    1.upto(6) do |day|
      @fiscal_year.expenses.create!(description: "経費#{day}", amount: day, category: :other, date: Date.new(2099, 1, day))
      @fiscal_year.revenues.create!(client_name: "取引先#{day}", amount: day, date: Date.new(2099, 1, day))
    end
    get fiscal_year_url(@fiscal_year)

    assert_select "#recent-expenses a", count: 5
    assert_select "#recent-expenses a", text: /経費6/
    assert_select "#recent-expenses a", text: /経費1/, count: 0
    assert_select "#recent-revenues a", count: 3
    assert_select "#recent-revenues a[href=?]", edit_fiscal_year_revenue_path(@fiscal_year, @fiscal_year.revenues.find_by!(client_name: "取引先6"), return_to: "dashboard")
  end

  test "an unexpected return_to can't redirect elsewhere" do
    post fiscal_year_expenses_url(@fiscal_year), params: {
      return_to: "https://example.com", expense: { description: "A", amount: 1000, category: "other", date: "2099-01-01" }
    }
    assert_redirected_to fiscal_year_expenses_url(@fiscal_year)
  end
end
