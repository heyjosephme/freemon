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
end
