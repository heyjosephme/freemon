# frozen_string_literal: true

require "test_helper"

class ExpenseListTest < ActionDispatch::IntegrationTest
  test "online purchases are marked, and in-person ones are flagged until a receipt is attached" do
    fiscal_year = FiscalYear.create!(year: 2099)
    fiscal_year.expenses.create!(description: "クラウド", amount: 1_300, category: :software, purchase_channel: :online,
                                 date: Date.new(2099, 1, 1))
    fiscal_year.expenses.create!(description: "コーヒー", amount: 450, category: :other, date: Date.new(2099, 1, 2))
    fiscal_year.expenses.create!(description: "文房具", amount: 880, category: :other, date: Date.new(2099, 1, 3),
                                 receipts: [ { io: StringIO.new("%PDF-1.4"), filename: "r.pdf", content_type: "application/pdf" } ])

    get fiscal_year_expenses_url(fiscal_year)

    cells = css_select("td").map(&:text).to_h { |text| [ text[/クラウド|コーヒー|文房具/], text ] }
    assert_match "(オンライン)", cells["クラウド"]
    assert_no_match "要領収書", cells["クラウド"]
    assert_match "(要領収書)", cells["コーヒー"]
    assert_no_match "要領収書", cells["文房具"]
  end

  test "assets show their method and this year's share, and later years add it to their total" do
    bought = FiscalYear.create!(year: 2098)
    bought.expenses.create!(description: "PC", amount: 500_000, category: :equipment, kind: :asset,
                            accounting_method: :normal_depreciation, useful_life: 4, date: Date.new(2098, 7, 15))
    following = FiscalYear.create!(year: 2099)
    following.expenses.create!(description: "コーヒー", amount: 1_000, category: :other, date: Date.new(2099, 1, 2))

    get fiscal_year_expenses_url(bought)
    assert_match "(資産・定額法4年)", response.body
    assert_select "tbody td", text: "¥62,500"

    get fiscal_year_expenses_url(following)
    assert_select "tfoot td", text: "前年以前に取得した資産の減価償却"
    assert_select "tfoot td", text: "¥125,000"
    assert_select "tfoot td", text: "¥126,000"
  end
end
