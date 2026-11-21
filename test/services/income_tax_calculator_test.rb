# frozen_string_literal: true

require "test_helper"

class IncomeTaxCalculatorTest < ActiveSupport::TestCase
  # Sole proprietor, blue 65, no salary: ¥5,000,000 revenue, ¥1,000,000 expenses.
  def build_year
    fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
    fiscal_year.revenues.create!(client_name: "C", amount: 5_000_000, date: Date.new(2099, 6, 1))
    fiscal_year.expenses.create!(description: "E", amount: 1_000_000, category: :other, business_ratio: 100, date: Date.new(2099, 6, 1))
    fiscal_year
  end

  test "baseline computation" do
    result = IncomeTaxCalculator.new(build_year).calculate

    assert_equal 90_909, result[:consumption_tax_expense] # 5,000,000 * 10 / 110 = 454,545, 2割特例 → 20%
    assert_equal 3_259_091, result[:business_income] # 5,000,000 - 1,000,000 - 90,909 - 650,000 (青色)
    assert_equal 3_259_091, result[:total_income]
    assert_equal 2_779_000, result[:taxable_income]  # less ¥480,000 基礎控除, rounded down to ¥1,000
    assert_equal 180_400, result[:income_tax_base]   # 2,779,000 * 10% - 97,500
    assert_equal 184_188, result[:total_tax]         # + 2.1% 復興税 (3,788)
    assert_equal 184_188, result[:final_tax]
    assert_in_delta 0.10, result[:income_tax_marginal_rate], 0.0001
  end

  test "extra income deductions reduce taxable income at the margin" do
    result = IncomeTaxCalculator.new(build_year, extra_income_deductions: 800_000).calculate

    assert_equal 1_979_000, result[:taxable_income]
    # 80,000 less tax than baseline (800,000 * 10% marginal)
    assert_equal 100_400, result[:income_tax_base]
  end

  test "extra business expenses reduce business profit before the blue deduction" do
    result = IncomeTaxCalculator.new(build_year, extra_business_expenses: 1_000_000).calculate

    assert_equal 1_779_000, result[:taxable_income]
    assert_equal 88_950, result[:income_tax_base] # crosses into the 5% bracket
  end

  test "消費税 expensed when paid is not deducted in its own year" do
    fiscal_year = build_year
    fiscal_year.update!(consumption_tax_timing: :when_paid)
    result = IncomeTaxCalculator.new(fiscal_year).calculate

    assert_equal 0, result[:consumption_tax_expense]
    assert_equal 3_350_000, result[:business_income] # 5,000,000 - 1,000,000 - 650,000 (青色)
  end

  test "still callable without keyword arguments (backward compatible)" do
    assert_nothing_raised { IncomeTaxCalculator.new(build_year).calculate }
  end

  test "marginal rate is zero when there is no taxable income" do
    fiscal_year = FiscalYear.create!(year: 2098, filing_type: :white)
    result = IncomeTaxCalculator.new(fiscal_year).calculate

    assert_equal 0, result[:taxable_income]
    assert_in_delta 0.0, result[:income_tax_marginal_rate], 0.0001
  end
end
