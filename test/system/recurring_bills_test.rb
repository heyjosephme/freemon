# frozen_string_literal: true

require "application_system_test_case"

class RecurringBillsTest < ApplicationSystemTestCase
  driven_by :rack_test

  setup do
    travel_to Date.new(2031, 6, 15)
    @fiscal_year = FiscalYear.create!(year: 2031)
  end

  teardown do
    travel_back
  end

  test "set up a varying bill, then record one month and skip the next from the dashboard" do
    visit fiscal_year_path(@fiscal_year)
    within("nav") { click_on "定期経費" }
    click_on "＋ 定期経費を追加"
    fill_in "内容 (Description)", with: "電気"
    select "水道光熱費 (Utilities)", from: "カテゴリ (Category)"
    fill_in "家事按分率 (Business Use %)", with: "30"
    fill_in "初回の支払日 (First payment)", with: "2031-05-26"
    click_on "追加"
    assert_text "定期経費を追加しました。"
    assert_text "毎回入力"

    visit fiscal_year_path(@fiscal_year)
    within("#recurring-bills li", text: "05/26") do
      fill_in "電気 5月分の金額", with: "9100"
      click_on "登録"
    end

    assert_current_path fiscal_year_path(@fiscal_year)
    assert_text "電気（5月分）を経費に登録しました。"
    assert_link text: %r{05/26.*電気.*¥9,100}
    expense = @fiscal_year.expenses.sole
    assert_equal [ Date.new(2031, 5, 26), 9_100, "utilities", 30, nil, "online" ],
                 [ expense.date, expense.amount, expense.category, expense.business_ratio, expense.invoice_eligible,
                   expense.purchase_channel ]

    within("#recurring-bills li", text: "06/26") { click_on "スキップ" }
    assert_text "電気（6月分）をスキップしました。"
    assert_selector "#recurring-bills", text: "未登録はありません"
  end
end
