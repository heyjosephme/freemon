# frozen_string_literal: true

require "test_helper"

class TaxSavingSimulatorTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
    @fiscal_year.revenues.create!(client_name: "C", amount: 5_000_000, date: Date.new(2099, 6, 1))
    @fiscal_year.expenses.create!(description: "E", amount: 1_000_000, category: :other, business_ratio: 100, date: Date.new(2099, 6, 1))
    @result = TaxSavingSimulator.new(@fiscal_year).calculate
  end

  test "marginal rate combines income bracket, reconstruction tax, and resident tax" do
    # 10% bracket → 0.10 * 1.021 + 0.10 = 0.2021
    assert_in_delta 0.2021, @result[:marginal_rate], 0.0001
  end

  test "income-deduction instrument saves about the marginal rate of the contribution" do
    shokibo = result_for(:shokibo)
    top = shokibo.scenarios.last

    assert_equal 840_000, top.annual
    assert_equal 70_000, top.monthly
    assert top.at_max
    assert_in_delta 169_764, top.savings, 5
    assert_in_delta 20.2, top.effective_rate, 0.2
  end

  test "savings increase monotonically with contribution size" do
    savings = result_for(:shokibo).scenarios.map(&:savings)
    assert_equal savings.sort, savings
  end

  test "business-expense instrument also reduces health insurance, so its effective rate is higher" do
    top = result_for(:sefuti).scenarios.last
    assert_equal 2_400_000, top.annual
    # exceeds the pure income+resident marginal (20.2%) because 国保 base also drops
    assert_operator top.effective_rate, :>, 22.0
  end

  test "iDeCo cap reflects the 第1号被保険者 monthly limit" do
    assert_equal 68_000, result_for(:ideco).scenarios.last.monthly
  end

  test "no savings when there is no taxable income" do
    empty = TaxSavingSimulator.new(FiscalYear.create!(year: 2097, filing_type: :white)).calculate
    assert_equal 0, empty[:taxable_income]
    assert(empty[:results].all? { |r| r.max_savings == 0 })
  end

  private

  def result_for(key)
    @result[:results].find { |r| r.instrument.key == key }
  end
end
