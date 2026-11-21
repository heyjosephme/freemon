# frozen_string_literal: true

require "test_helper"

class TaxReserveEstimatorTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
    @fiscal_year.revenues.create!(client_name: "C", amount: 5_000_000, date: Date.new(2099, 6, 1))
    @fiscal_year.expenses.create!(description: "E", amount: 1_000_000, category: :other, business_ratio: 100, date: Date.new(2099, 6, 1))
    @reserve = TaxReserveEstimator.new(@fiscal_year).calculate
  end

  test "combines income, consumption, resident and health taxes" do
    by_key = @reserve[:components].to_h { |c| [ c.key, c.amount ] }

    # 消費税 90,909 (5,000,000 × 10 / 110 × 20%) is 租税公課, so every income-based figure starts
    # from 事業所得 3,259,091 (5,000,000 − 1,000,000 − 90,909 − 650,000).
    assert_equal 184_188, by_key[:income_tax]
    assert_equal 90_909, by_key[:consumption_tax]
    assert_equal 285_400, by_key[:resident_tax]
    assert_equal 358_324, by_key[:health_insurance]
    assert_equal by_key.values.sum, @reserve[:total]
  end

  test "reserve rate is the total expressed as a percentage of revenue" do
    expected = (@reserve[:total] * 100.0 / 5_000_000).round(1)
    assert_in_delta expected, @reserve[:reserve_rate], 0.01
  end

  test "monthly reserve is one twelfth of the total" do
    assert_equal @reserve[:total] / 12, @reserve[:monthly]
  end

  test "negative tax positions are clamped to zero, not negative reserves" do
    # An empty year would have a refundable/zero income tax; reserve never goes negative.
    empty = TaxReserveEstimator.new(FiscalYear.create!(year: 2097, filing_type: :white)).calculate
    assert empty[:components].all? { |c| c.amount >= 0 }
    assert_operator empty[:total], :>=, 0
  end
end
