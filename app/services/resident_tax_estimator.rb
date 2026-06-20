# frozen_string_literal: true

# Estimates 住民税 (resident tax) for a fiscal year from an IncomeTaxCalculator
# result hash. This is a 概算 (estimate): resident tax actually uses slightly
# different deduction amounts than income tax (notably 基礎控除 ¥430,000 vs
# ¥480,000) and a simplified 調整控除. Rates are the standard 10% (市町村民税 6%
# + 道府県民税 4%); municipalities may differ.
#
# All integer arithmetic — no floats — so results are exact.
class ResidentTaxEstimator
  RATE_PERCENT = 10        # 所得割 (市町村民税 6% + 道府県民税 4%)
  PER_CAPITA = 5_000       # 均等割 (森林環境税 ¥1,000 を含む)
  BASIC_DEDUCTION = 430_000
  ADJUSTMENT_CREDIT = 2_500 # 調整控除 (簡易)

  def initialize(income_tax_result, extra_income_deductions: 0)
    @it = income_tax_result
    @extra_income_deductions = extra_income_deductions
  end

  def calculate
    deductions = BASIC_DEDUCTION +
                 @it[:social_insurance_from_salary] +
                 @it[:additional_deductions] +
                 @extra_income_deductions

    taxable = [ @it[:total_income] - deductions, 0 ].max
    taxable = taxable / 1000 * 1000 # round down to nearest ¥1,000

    income_levy = [ taxable * RATE_PERCENT / 100 - ADJUSTMENT_CREDIT, 0 ].max
    per_capita = taxable.positive? ? PER_CAPITA : 0

    {
      taxable: taxable,
      income_levy: income_levy,
      per_capita: per_capita,
      total: income_levy + per_capita
    }
  end
end
