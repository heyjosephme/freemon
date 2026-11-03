# frozen_string_literal: true

require "application_system_test_case"

class ExpenseFormTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup do
    @fiscal_year = FiscalYear.create!(year: 2099)
    @expense = @fiscal_year.expenses.create!(description: "技術書", amount: 3_520, category: :books, business_ratio: 100,
                                             invoice_eligible: nil, date: Date.new(2099, 8, 15))
  end

  test "an unset インボイス status stays unset when the expense is edited" do
    visit edit_fiscal_year_expense_path(@fiscal_year, @expense)
    assert_field "インボイス (Invoice)", with: ""

    fill_in "内容 (Description)", with: "技術書（Rails）"
    click_on "更新"

    assert_equal "技術書（Rails）", @expense.reload.description
    assert_nil @expense.invoice_eligible
  end

  test "choosing あり or なし records the status" do
    { "あり（適格請求書あり）" => true, "なし" => false }.each do |option, expected|
      visit edit_fiscal_year_expense_path(@fiscal_year, @expense)
      select option, from: "インボイス (Invoice)"
      click_on "更新"

      assert_equal expected, @expense.reload.invoice_eligible, option
    end
  end

  test "the form records where an expense was bought" do
    visit edit_fiscal_year_expense_path(@fiscal_year, @expense)
    assert_field "購入方法 (Purchased)", with: "in_person"

    select "オンライン", from: "購入方法 (Purchased)"
    click_on "更新"

    assert @expense.reload.online?
  end

  test "an asset entered through the form gets its method from the amount" do
    visit new_fiscal_year_expense_path(@fiscal_year)
    fill_in "内容 (Description)", with: "MacBook Pro"
    fill_in "金額 税込 (Amount, tax included)", with: "298000"
    select "設備・資産", from: "区分 (Type)"
    click_on "登録"

    expense = @fiscal_year.expenses.find_by!(description: "MacBook Pro")
    assert_equal [ "asset", "small_asset_special" ], [ expense.kind, expense.accounting_method ]
  end

  test "new expenses start unset, so nothing is credited by accident" do
    visit new_fiscal_year_expense_path(@fiscal_year)
    assert_field "インボイス (Invoice)", with: ""
  end
end
