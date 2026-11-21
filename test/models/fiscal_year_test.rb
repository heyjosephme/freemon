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

  test "a year's expenses count depreciation of assets bought in earlier years" do
    later = FiscalYear.create!(year: 2031)
    @fiscal_year.expenses.create!(description: "コーヒー", amount: 1_000, category: :other, date: Date.new(2030, 3, 1))
    @fiscal_year.expenses.create!(description: "PC", amount: 500_000, category: :equipment, kind: :asset,
                                  accounting_method: :normal_depreciation, useful_life: 4, date: Date.new(2030, 7, 15))
    later.expenses.create!(description: "コーヒー", amount: 2_000, category: :other, date: Date.new(2031, 3, 1))

    assert_equal 1_000 + 62_500, @fiscal_year.total_expenses
    assert_equal 2_000 + 125_000, later.total_expenses
  end

  test "accrued 消費税 is this year's 租税公課" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))
    @fiscal_year.expenses.create!(description: "家賃", amount: 300_000, category: :office, date: Date.new(2030, 6, 1))
    later = FiscalYear.create!(year: 2031)

    assert_equal 20_000, @fiscal_year.consumption_tax_payable # 1,100,000 × 10 / 110 × 20% (2割特例)
    assert_equal 20_000, @fiscal_year.consumption_tax_expense
    assert_equal 1_100_000 - 300_000 - 20_000, @fiscal_year.business_profit
    assert_equal 0, later.consumption_tax_expense
  end

  test "消費税 expensed when paid moves to the following year, on top of that year's own" do
    @fiscal_year.update!(consumption_tax_timing: :when_paid)
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))
    later = FiscalYear.create!(year: 2031)
    later.revenues.create!(client_name: "取引先", amount: 550_000, date: Date.new(2031, 6, 1))

    assert_equal 0, @fiscal_year.consumption_tax_expense
    assert_equal 1_100_000, @fiscal_year.business_profit
    assert_equal 20_000 + 10_000, later.consumption_tax_expense # 2030's, paid in 2031, plus 2031's accrued
    assert_equal 550_000 - 30_000, later.business_profit
  end

  test "new entries start today in the current year, else on January 1st" do
    travel_to Date.new(2031, 6, 15) do
      assert_equal Date.new(2031, 6, 15), FiscalYear.new(year: 2031).default_entry_date
      assert_equal Date.new(2030, 1, 1), @fiscal_year.default_entry_date
    end
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
