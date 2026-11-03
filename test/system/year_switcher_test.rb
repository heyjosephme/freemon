# frozen_string_literal: true

require "application_system_test_case"

# Runs in a real browser: closing the menu on an outside click is JavaScript.
class YearSwitcherTest < ApplicationSystemTestCase
  test "the navbar menu switches years and closes on an outside click" do
    older = FiscalYear.create!(year: 2030)
    FiscalYear.create!(year: 2031)

    visit fiscal_year_path(older)
    find("nav summary", text: "2030年").click
    assert_link "2031年"

    find("h1").click
    assert_no_link "2031年"

    find("nav summary").click
    click_on "2031年"
    assert_selector "h1", text: "2031年"
  end
end
