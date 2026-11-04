# frozen_string_literal: true

require "application_system_test_case"

# Real browser: 複製's row loads into a turbo-frame, and Esc/キャンセル run in JavaScript.
class RevenueCopyTest < ApplicationSystemTestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2031)
    @revenue = @fiscal_year.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2031, 5, 31))
  end

  test "複製 opens a filled-in row under the revenue, ready for Enter" do
    visit fiscal_year_path(@fiscal_year)
    within("#recent-revenues") { click_on "複製" }

    within("##{frame}") do
      assert_field "取引先", with: "株式会社テックコープ"
      assert_field "日付", with: "2031-06-30"
      amount = find_field("金額（税込）", with: "550000")
      assert_equal amount[:id], evaluate_script("document.activeElement.id"), "the amount has the focus"
      amount.send_keys("560000", :enter) # selected, so typing replaces it
    end

    assert_text "売上を登録しました。"
    assert_current_path fiscal_year_path(@fiscal_year)
    assert_selector "#recent-revenues li", text: %r{06/30.*株式会社テックコープ.*¥560,000}m
    assert_equal [ [ Date.new(2031, 5, 31), 550_000 ], [ Date.new(2031, 6, 30), 560_000 ] ],
                 @fiscal_year.revenues.order(:date).pluck(:date, :amount)
  end

  test "on the revenue list the row opens below the revenue; キャンセル and Esc close it" do
    visit fiscal_year_revenues_path(@fiscal_year)
    assert_no_selector "##{frame}", visible: :visible

    click_on "複製"
    assert_selector "##{frame} form"
    click_on "キャンセル"
    assert_no_selector "##{frame} form"

    click_on "複製"
    find_field("金額（税込）").send_keys(:escape)
    assert_no_selector "##{frame} form"

    click_on "複製"
    within("##{frame}") { click_on "登録" }
    assert_text "売上を登録しました。"
    assert_equal 2, @fiscal_year.revenues.count
  end

  private

  def frame = "copy_revenue_#{@revenue.id}"
end
