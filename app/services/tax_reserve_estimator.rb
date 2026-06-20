# frozen_string_literal: true

# Estimates how much cash a freelancer should set aside for the taxes and
# public charges that come due AFTER the fiscal year ends: income tax,
# consumption tax (cheapest method), and the 住民税 / 国保 estimates.
#
# This bridges cashflow and tax: the headline figure (and "% of each invoice")
# tells the user what to reserve so a spring tax bill isn't a surprise.
class TaxReserveEstimator
  Component = Data.define(:key, :label, :amount, :timing)

  def initialize(fiscal_year, include_care: false)
    @fiscal_year = fiscal_year
    @include_care = include_care
  end

  def calculate
    income_tax = IncomeTaxCalculator.new(@fiscal_year).calculate
    consumption_tax = ConsumptionTaxCalculator.new(@fiscal_year).calculate
    resident = ResidentTaxEstimator.new(income_tax).calculate
    health = HealthInsuranceEstimator.new(income_tax, include_care: @include_care).calculate

    components = [
      Component.new(key: :income_tax, label: "所得税 (Income Tax)",
                    amount: clamp(income_tax[:final_tax]), timing: "翌年 3/15 まで"),
      Component.new(key: :consumption_tax, label: "消費税 (Consumption Tax)",
                    amount: clamp(consumption_tax[:methods][consumption_tax[:recommended]]), timing: "翌年 3/31 まで"),
      Component.new(key: :resident_tax, label: "住民税 概算 (Resident Tax, est.)",
                    amount: resident[:total], timing: "翌年 6月〜（普通徴収 4期）"),
      Component.new(key: :health_insurance, label: "国民健康保険 概算 (Health Insurance, est.)",
                    amount: health[:total], timing: "翌年 6月〜翌々年 3月")
    ]

    total = components.sum(&:amount)
    revenue = @fiscal_year.total_revenue

    {
      components: components,
      total: total,
      revenue: revenue,
      reserve_rate: revenue.positive? ? (total * 100.0 / revenue).round(1) : 0.0,
      monthly: total / 12,
      recommended_consumption_method: consumption_tax[:recommended],
      income_tax_detail: income_tax,
      resident_detail: resident,
      health_detail: health
    }
  end

  private

  def clamp(amount)
    [ amount, 0 ].max
  end
end
