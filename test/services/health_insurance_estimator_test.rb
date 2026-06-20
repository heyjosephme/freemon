# frozen_string_literal: true

require "test_helper"

class HealthInsuranceEstimatorTest < ActiveSupport::TestCase
  test "medical + support from income, care excluded by default" do
    result = HealthInsuranceEstimator.new({ total_income: 3_350_000 }).calculate

    assert_equal 2_920_000, result[:base]      # 3,350,000 - 430,000
    assert_equal 272_432, result[:medical]     # 2,920,000 * 7.71% + 47,300
    assert_equal 95_348, result[:support]      # 2,920,000 * 2.69% + 16,800
    assert_equal 0, result[:care]
    assert_equal 367_780, result[:total]
  end

  test "care component included when requested (ages 40-64)" do
    result = HealthInsuranceEstimator.new({ total_income: 3_350_000 }, include_care: true).calculate

    assert_equal 83_468, result[:care]         # 2,920,000 * 2.29% + 16,600
    assert_equal 451_248, result[:total]
  end

  test "each component is capped at high income" do
    result = HealthInsuranceEstimator.new({ total_income: 50_000_000 }).calculate

    assert_equal 650_000, result[:medical]
    assert_equal 240_000, result[:support]
  end

  test "only per-capita charges when income is below the basic deduction" do
    result = HealthInsuranceEstimator.new({ total_income: 200_000 }).calculate

    assert_equal 0, result[:base]
    assert_equal 47_300 + 16_800, result[:total] # 均等割 only
  end
end
