# frozen_string_literal: true

class IncomeTaxCalculator
  BASIC_DEDUCTION = 480_000 # 基礎控除

  BLUE_DEDUCTIONS = { blue_65: 650_000, blue_10: 100_000, white: 0 }.freeze

  # 所得税 progressive brackets
  INCOME_TAX_BRACKETS = [
    { limit: 1_950_000,      rate: 0.05, deduction: 0 },
    { limit: 3_300_000,      rate: 0.10, deduction: 97_500 },
    { limit: 6_950_000,      rate: 0.20, deduction: 427_500 },
    { limit: 9_000_000,      rate: 0.23, deduction: 636_000 },
    { limit: 18_000_000,     rate: 0.33, deduction: 1_536_000 },
    { limit: 40_000_000,     rate: 0.40, deduction: 2_796_000 },
    { limit: Float::INFINITY, rate: 0.45, deduction: 4_796_000 }
  ].freeze

  RECONSTRUCTION_TAX_RATE = 0.021 # 復興特別所得税

  attr_reader :fiscal_year

  def initialize(fiscal_year)
    @fiscal_year = fiscal_year
  end

  def calculate
    result = {}
    si = fiscal_year.salary_income

    # 1. Salary income (給与所得)
    result[:gross_salary] = si&.gross_salary || 0
    result[:salary_deduction] = si&.salary_deduction || 0
    result[:salary_income] = si&.salary_income_amount || 0

    # 2. Business income (事業所得)
    result[:business_revenue] = fiscal_year.total_revenue
    result[:total_expenses] = fiscal_year.total_expenses
    result[:blue_deduction_amount] = BLUE_DEDUCTIONS[fiscal_year.filing_type.to_sym]

    business_profit_before_blue = result[:business_revenue] - result[:total_expenses]
    result[:blue_deduction_applied] = if business_profit_before_blue > 0
      [ result[:blue_deduction_amount], business_profit_before_blue ].min
    else
      0
    end
    result[:business_income] = business_profit_before_blue - result[:blue_deduction_applied]

    # 3. Loss offset (損益通算)
    if result[:business_income] < 0
      result[:loss_offset] = result[:business_income]
      result[:total_income] = [ result[:salary_income] + result[:business_income], 0 ].max
    else
      result[:loss_offset] = 0
      result[:total_income] = result[:salary_income] + result[:business_income]
    end

    # 4. Deductions (所得控除)
    result[:basic_deduction] = BASIC_DEDUCTION
    result[:social_insurance_from_salary] = si&.social_insurance || 0
    result[:additional_deductions] = fiscal_year.total_deductions_amount
    result[:total_deductions] = result[:basic_deduction] +
                                 result[:social_insurance_from_salary] +
                                 result[:additional_deductions]

    # 5. Taxable income (課税所得) — floored at 0, rounded down to nearest 1000
    taxable = [ result[:total_income] - result[:total_deductions], 0 ].max
    result[:taxable_income] = (taxable / 1000) * 1000

    # 6. Income tax (所得税)
    result[:income_tax_base] = compute_income_tax(result[:taxable_income])
    result[:reconstruction_tax] = (result[:income_tax_base] * RECONSTRUCTION_TAX_RATE).to_i
    result[:total_tax] = result[:income_tax_base] + result[:reconstruction_tax]

    # 7. Tax already paid
    result[:tax_withheld] = si&.tax_withheld || 0
    result[:final_tax] = result[:total_tax] - result[:tax_withheld]

    result
  end

  private

  def compute_income_tax(taxable_income)
    return 0 if taxable_income <= 0

    bracket = INCOME_TAX_BRACKETS.find { |b| taxable_income <= b[:limit] }
    ((taxable_income * bracket[:rate]) - bracket[:deduction]).to_i
  end
end
