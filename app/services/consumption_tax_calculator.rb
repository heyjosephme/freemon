# frozen_string_literal: true

class ConsumptionTaxCalculator
  SIMPLIFIED_DEEMED_RATE = 0.50 # Type 5 (IT/services): みなし仕入率 50%
  SPECIAL_RATE = 0.20           # 2割特例

  attr_reader :fiscal_year

  def initialize(fiscal_year)
    @fiscal_year = fiscal_year
  end

  def calculate
    result = {}

    # Output tax: consumption tax collected from revenue
    total_revenue = fiscal_year.revenues.sum(:amount)
    result[:total_revenue_tax_included] = total_revenue
    result[:output_tax] = total_revenue * 10 / 110

    # Input tax: from invoice-eligible expenses only (after 家事按分)
    invoice_expenses = fiscal_year.expenses.where(invoice_eligible: true)
    result[:input_tax] = invoice_expenses.sum("amount * 10 / 110 * business_ratio / 100")
    result[:non_eligible_tax] = fiscal_year.expenses.where(invoice_eligible: false)
                                  .sum("amount * 10 / 110 * business_ratio / 100")

    # Method 1: 本則課税 (Standard) — can be negative (= refund)
    result[:standard_tax] = result[:output_tax] - result[:input_tax]

    # Method 2: 簡易課税 (Simplified)
    result[:simplified_tax] = (result[:output_tax] * SIMPLIFIED_DEEMED_RATE).to_i

    # Method 3: 2割特例 (20% Special Rule)
    result[:special_tax] = (result[:output_tax] * SPECIAL_RATE).to_i

    # Recommendation: lowest amount (most advantageous)
    methods = {
      standard: result[:standard_tax],
      simplified: result[:simplified_tax],
      special: result[:special_tax]
    }
    result[:recommended] = methods.min_by { |_, v| v }.first
    result[:methods] = methods

    result
  end
end
