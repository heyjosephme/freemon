# frozen_string_literal: true

require "test_helper"

class ConsumptionTaxCalculatorTest < ActiveSupport::TestCase
  # ¥1,100,000 of sales, and three ¥110,000 expenses: with an invoice, without, and unset.
  setup do
    fiscal_year = FiscalYear.create!(year: 2099)
    fiscal_year.revenues.create!(client_name: "C", amount: 1_100_000, date: Date.new(2099, 6, 1))
    [ true, false, nil ].each do |invoice|
      fiscal_year.expenses.create!(description: "E", amount: 110_000, category: :other, business_ratio: 100,
                                   invoice_eligible: invoice, date: Date.new(2099, 6, 1))
    end
    @result = ConsumptionTaxCalculator.new(fiscal_year).calculate
  end

  test "本則課税 only credits expenses with an invoice" do
    assert_equal 100_000, @result[:output_tax]   # 1,100,000 × 10/110
    assert_equal 10_000, @result[:input_tax]     # the one ¥110,000 expense with an invoice
    assert_equal 90_000, @result[:standard_tax]
  end

  test "expenses without an invoice or with an unset status are reported as not creditable" do
    assert_equal 20_000, @result[:non_eligible_tax]
  end
end
