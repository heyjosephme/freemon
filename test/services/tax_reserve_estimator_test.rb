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

    assert_equal 193_479, by_key[:income_tax]
    assert_operator by_key[:consumption_tax], :>, 0
    assert_equal 294_500, by_key[:resident_tax]
    assert_equal 367_780, by_key[:health_insurance]
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
