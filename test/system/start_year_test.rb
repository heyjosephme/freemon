# frozen_string_literal: true

require "application_system_test_case"

class StartYearTest < ApplicationSystemTestCase
  driven_by :rack_test

  test "starting this year's books from the latest year's dashboard" do
    travel_to Date.new(2031, 6, 1) do
      FiscalYear.create!(year: 2030, filing_type: :white)

      visit root_path
      assert_selector "h1", text: "2030年"
      click_on "2031年の帳簿を始める"

      assert_text "確定申告年度を作成しました。"
      assert_selector "h1", text: "2031年"
      assert FiscalYear.find_by!(year: 2031).white?
    end
  end
end
