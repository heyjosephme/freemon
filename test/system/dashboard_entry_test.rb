# frozen_string_literal: true

require "application_system_test_case"

class DashboardEntryTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup do
    travel_to Date.new(2031, 6, 15)
    @fiscal_year = FiscalYear.create!(year: 2031)
  end

  teardown do
    travel_back
  end

  test "quick-adding an expense stays on the dashboard" do
    visit fiscal_year_path(@fiscal_year)
    within("#quick-add-expense") do
      fill_in "内容", with: "コワーキング 6月"
      fill_in "金額（税込）", with: "30000"
      select "事務所・コワーキング", from: "カテゴリ"
      click_on "追加"
    end

    assert_current_path fiscal_year_path(@fiscal_year)
    assert_text "経費を登録しました。"
    assert_link text: /06\/15.*コワーキング 6月.*¥30,000/
    expense = @fiscal_year.expenses.sole
    assert_equal [ Date.new(2031, 6, 15), 30_000, "office", 100, nil ],
                 [ expense.date, expense.amount, expense.category, expense.business_ratio, expense.invoice_eligible ]
  end

  test "a quick-add with a problem opens the full form, which still comes back here" do
    visit fiscal_year_path(@fiscal_year)
    within("#quick-add-expense") do
      fill_in "金額（税込）", with: "1200"
      click_on "追加"
    end

    assert_selector "h1", text: "経費の追加"
    fill_in "内容 (Description)", with: "文房具"
    click_on "登録"

    assert_current_path fiscal_year_path(@fiscal_year)
    assert_equal [ [ "文房具", 1_200 ] ], @fiscal_year.expenses.pluck(:description, :amount)
  end

  test "full forms and edits opened from the dashboard come back to it" do
    visit fiscal_year_path(@fiscal_year)
    click_on "詳細入力"
    fill_in "内容 (Description)", with: "MacBook Pro"
    fill_in "金額 税込 (Amount, tax included)", with: "298000"
    click_on "登録"
    assert_current_path fiscal_year_path(@fiscal_year)

    click_on "MacBook Pro"
    fill_in "金額 税込 (Amount, tax included)", with: "280000"
    click_on "更新"
    assert_current_path fiscal_year_path(@fiscal_year)
    assert_equal 280_000, @fiscal_year.expenses.sole.amount

    click_on "＋ 売上を追加"
    fill_in "取引先名 (Client Name)", with: "テスト社"
    fill_in "金額 (税込) (Amount, tax included)", with: "550000"
    click_on "登録"
    assert_current_path fiscal_year_path(@fiscal_year)
    assert_text "売上を登録しました。"
    assert_equal Date.new(2031, 6, 15), @fiscal_year.revenues.sole.date
  end

  test "cancelling a form opened from the dashboard goes back to it" do
    visit fiscal_year_path(@fiscal_year)
    click_on "詳細入力"
    click_on "キャンセル"

    assert_current_path fiscal_year_path(@fiscal_year)
  end
end
