# frozen_string_literal: true

# Estimates 国民健康保険料 (National Health Insurance) for a fiscal year from an
# IncomeTaxCalculator result hash. Highly municipality-dependent — defaults
# model a standard 東京23区 profile (~2024). Rates are basis points (bps) so
# the math stays integer-exact. Low-income 軽減 (7/5/2割) is NOT modeled.
#
#   component = min(cap, base × bps / 10_000 + per_capita)
#   base      = max(0, 総所得金額等 − 基礎控除)
class HealthInsuranceEstimator
  BASIC_DEDUCTION = 430_000

  # 医療分 / 後期高齢者支援分 / 介護分 (介護 applies to ages 40–64 only)
  MEDICAL = { bps: 771, per_capita: 47_300, cap: 650_000 }.freeze
  SUPPORT = { bps: 269, per_capita: 16_800, cap: 240_000 }.freeze
  CARE    = { bps: 229, per_capita: 16_600, cap: 170_000 }.freeze

  def initialize(income_tax_result, include_care: false)
    @it = income_tax_result
    @include_care = include_care
  end

  def calculate
    base = [ @it[:total_income] - BASIC_DEDUCTION, 0 ].max

    medical = component(base, MEDICAL)
    support = component(base, SUPPORT)
    care = @include_care ? component(base, CARE) : 0

    {
      base: base,
      medical: medical,
      support: support,
      care: care,
      total: medical + support + care
    }
  end

  private

  def component(base, params)
    [ base * params[:bps] / 10_000 + params[:per_capita], params[:cap] ].min
  end
end
