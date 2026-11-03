# frozen_string_literal: true

require "application_system_test_case"

# Runs in a real browser: showing the asset fields is JavaScript.
class AssetFieldsTest < ApplicationSystemTestCase
  test "the asset fields appear only once 区分 is 設備・資産" do
    fiscal_year = FiscalYear.create!(year: 2099)
    visit new_fiscal_year_expense_path(fiscal_year)
    assert_no_field "償却方法 (Accounting method)"

    select "設備・資産", from: "区分 (Type)"
    assert_field "償却方法 (Accounting method)"
    assert_field "耐用年数 (Useful life, years)"

    select "経費", from: "区分 (Type)"
    assert_no_field "償却方法 (Accounting method)"
  end
end
