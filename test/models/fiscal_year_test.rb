# frozen_string_literal: true

require "test_helper"

class FiscalYearTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "filing deadlines open on January 1st after the year ends" do
    assert_empty @fiscal_year.open_filing_deadlines(Date.new(2030, 12, 31))
    assert_equal({ "所得税" => Date.new(2031, 3, 15), "消費税" => Date.new(2031, 3, 31) },
                 @fiscal_year.open_filing_deadlines(Date.new(2031, 1, 1)))
  end

  test "each deadline drops off once it has passed" do
    assert_equal [ "所得税", "消費税" ], @fiscal_year.open_filing_deadlines(Date.new(2031, 3, 15)).keys
    assert_equal [ "消費税" ], @fiscal_year.open_filing_deadlines(Date.new(2031, 3, 16)).keys
    assert_empty @fiscal_year.open_filing_deadlines(Date.new(2031, 4, 1))
  end

  test "home is this year, else the most recent earlier year, else the latest" do
    travel_to Date.new(2031, 6, 1) do
      assert_equal @fiscal_year, FiscalYear.home

      future = FiscalYear.create!(year: 2033)
      assert_equal @fiscal_year, FiscalYear.home, "an earlier year beats a future one"

      current = FiscalYear.create!(year: 2031)
      assert_equal current, FiscalYear.home

      current.destroy
      @fiscal_year.destroy
      assert_equal future, FiscalYear.home
    end
  end
end
