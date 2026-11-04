# frozen_string_literal: true

require "test_helper"

class RecurringExpensesTest < ActionDispatch::IntegrationTest
  setup do
    travel_to Date.new(2030, 6, 3)
    @fiscal_year = FiscalYear.create!(year: 2030)
    @rent = RecurringExpense.create!(description: "家賃", amount: 120_000, category: :office, business_ratio: 30,
                                     starts_on: Date.new(2030, 5, 27))
    @power = RecurringExpense.create!(description: "電気", category: :utilities, business_ratio: 30, starts_on: Date.new(2030, 6, 26))
  end

  teardown do
    travel_back
  end

  test "the dashboard lists the bills due through this month, with fixed amounts filled in" do
    get fiscal_year_url(@fiscal_year)

    assert_select "#recurring-bills li", count: 3
    assert_select "#recurring-bills li", text: %r{05/27家賃} do
      assert_select "input[name=month][value='2030-05-01']"
      assert_select "input[name=amount][value='120000'][required]"
    end
    assert_select "#recurring-bills li", text: %r{06/26電気} do
      assert_select "input[name=amount]:not([value])"
      assert_select "label", text: "電気 6月分の金額"
    end
    assert_select "#recurring-bills button", text: "固定額の2件をまとめて登録"
  end

  test "登録 saves the bill as an expense, and its row goes away" do
    post record_recurring_expense_url(@power), params: { month: "2030-06-01", amount: "8200" }

    assert_redirected_to fiscal_year_url(@fiscal_year)
    expense = @fiscal_year.expenses.sole
    assert_equal [ "電気", 8_200, "utilities", 30, Date.new(2030, 6, 26), @power ],
                 [ expense.description, expense.amount, expense.category, expense.business_ratio, expense.date, expense.recurring_expense ]

    follow_redirect!
    assert_match "電気（6月分）を経費に登録しました。", response.body
    assert_select "#recurring-bills li", count: 2
    assert_select "#recurring-bills li", text: /電気/, count: 0
  end

  test "a varying bill isn't recorded without its amount" do
    post record_recurring_expense_url(@power), params: { month: "2030-06-01", amount: "" }
    follow_redirect!

    assert_match "電気（6月分）を登録できませんでした: 金額を1円以上で入力してください", response.body
    assert_empty @fiscal_year.expenses
  end

  test "only months that are due can be recorded or skipped" do
    post record_recurring_expense_url(@power), params: { month: "2030-05-01", amount: "8200" }
    assert_redirected_to recurring_expenses_url
    assert_empty @fiscal_year.expenses

    post skip_recurring_expense_url(@power), params: { month: "not-a-date" }
    assert_response :bad_request
  end

  test "スキップ hides the month until it's unchecked on the template" do
    post skip_recurring_expense_url(@rent), params: { month: "2030-05-01" }
    assert_redirected_to fiscal_year_url(@fiscal_year)
    follow_redirect!
    assert_match "家賃（5月分）をスキップしました。", response.body
    assert_select "#recurring-bills li", text: %r{05/27}, count: 0

    get edit_recurring_expense_url(@rent)
    assert_select "input[type=checkbox][name='recurring_expense[skipped_months][]'][value='2030-05-01'][checked]"

    patch recurring_expense_url(@rent), params: { recurring_expense: { skipped_months: [ "" ] } }
    assert_empty @rent.reload.skipped_months
  end

  test "まとめて登録 records every fixed-amount bill and leaves the varying ones" do
    post record_all_recurring_expenses_url, params: { fiscal_year_id: @fiscal_year.id }

    assert_redirected_to fiscal_year_url(@fiscal_year)
    assert_equal [ [ "家賃", Date.new(2030, 5, 27) ], [ "家賃", Date.new(2030, 6, 27) ] ],
                 @fiscal_year.expenses.order(:date).pluck(:description, :date)
    follow_redirect!
    assert_match "定期経費を2件登録しました。", response.body
    assert_select "#recurring-bills li", count: 1
  end

  test "once everything is recorded the dashboard says so; past years list theirs, future years nothing" do
    @power.update!(starts_on: Date.new(2030, 7, 26))
    @rent.update!(starts_on: Date.new(2029, 11, 27))
    previous = FiscalYear.create!(year: 2029)
    following = FiscalYear.create!(year: 2031)

    get fiscal_year_url(previous)
    assert_select "#recurring-bills li", count: 2 # November and December 2029

    get fiscal_year_url(following)
    assert_select "#recurring-bills li", count: 0
    assert_select "#recurring-bills", text: /未登録はありません/
  end

  test "templates are added and listed, and deleting one keeps its expenses" do
    post recurring_expenses_url, params: { recurring_expense: {
      description: "インターネット", amount: "5500", category: "communication", business_ratio: "50", invoice_eligible: "true",
      purchase_channel: "online", interval_months: "1", starts_on: "2030-06-27"
    } }
    assert_redirected_to recurring_expenses_url
    follow_redirect!
    assert_select "tr", text: /インターネット.*¥5,500.*50%.*毎月27日.*2030年6月〜/
    assert_select "tr", text: /電気.*毎回入力/

    @rent.expense_for(Date.new(2030, 5, 1)).save!
    delete recurring_expense_url(@rent)

    assert_redirected_to recurring_expenses_url
    assert_not RecurringExpense.exists?(@rent.id)
    assert_equal [ "家賃" ], @fiscal_year.expenses.pluck(:description)
  end

  test "an invalid template shows what's wrong" do
    post recurring_expenses_url, params: { recurring_expense: { description: "", amount: "0", interval_months: "1", starts_on: "" } }

    assert_response :unprocessable_entity
    assert_match "内容を入力してください", response.body
    assert_match "金額は1円以上で入力してください", response.body
    assert_match "初回の支払日を入力してください", response.body
  end

  test "定期経費にする copies an expense into the new-template form" do
    expense = @fiscal_year.expenses.create!(description: "携帯", amount: 4_800, category: :communication, business_ratio: 50,
                                            date: Date.new(2030, 5, 20))

    get edit_fiscal_year_expense_url(@fiscal_year, expense)
    assert_select "a[href='#{new_recurring_expense_path(from_expense: expense.id)}']", text: "定期経費にする"

    get new_recurring_expense_url(from_expense: expense.id)
    assert_select "input[name='recurring_expense[description]'][value='携帯']"
    assert_select "input[name='recurring_expense[amount]'][value='4800']"
    assert_select "input[name='recurring_expense[starts_on]'][value='2030-06-20']"
  end

  test "recorded bills are tagged in the expense list, without the hint that ¥100,000 might be an asset" do
    @rent.expense_for(Date.new(2030, 5, 1)).save!

    get fiscal_year_expenses_url(@fiscal_year)
    assert_select "td", text: /家賃\(定期\)/
    assert_no_match "資産？", response.body
  end
end
