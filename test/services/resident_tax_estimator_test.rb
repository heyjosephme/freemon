# frozen_string_literal: true

require "test_helper"

class ResidentTaxEstimatorTest < ActiveSupport::TestCase
  def income_tax_result(total_income:, social_insurance: 0, additional: 0)
    { total_income: total_income, social_insurance_from_salary: social_insurance, additional_deductions: additional }
  end

  test "computes 所得割 plus 均等割 from an income-tax result" do
    result = ResidentTaxEstimator.new(income_tax_result(total_income: 3_350_000)).calculate

    assert_equal 2_920_000, result[:taxable]    # 3,350,000 - 430,000 基礎控除
    assert_equal 289_500, result[:income_levy]  # 292,000 (10%) - 2,500 調整控除
    assert_equal 5_000, result[:per_capita]
    assert_equal 294_500, result[:total]
  end

  test "extra income deductions lower the resident-tax base" do
    result = ResidentTaxEstimator.new(
      income_tax_result(total_income: 3_350_000), extra_income_deductions: 800_000
    ).calculate

    assert_equal 2_120_000, result[:taxable]
    # 80,000 less levy than the baseline (800,000 * 10%)
    assert_equal 209_500, result[:income_levy]
  end

  test "no levy or per-capita charge when there is no taxable income" do
    result = ResidentTaxEstimator.new(income_tax_result(total_income: 300_000)).calculate

    assert_equal 0, result[:taxable]
    assert_equal 0, result[:total]
  end
end
