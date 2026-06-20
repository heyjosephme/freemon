# frozen_string_literal: true

# What-if simulator for the big freelancer tax-saving instruments. For each,
# it re-runs the tax calculators with a hypothetical contribution and reports
# the actual tax saved (income + resident, plus 国保 for expense-type schemes)
# at a few preset monthly amounts and the legal maximum.
#
# Two kinds of instrument:
#   :income_deduction — 所得控除 (小規模企業共済, iDeCo). Lowers income & resident
#                       tax, but NOT 国保 (国保 ignores these deductions).
#   :business_expense — 必要経費 (経営セーフティ共済). Lowers 事業所得, so it also
#                       shrinks the 国保 base.
class TaxSavingSimulator
  RECONSTRUCTION_RATE = 0.021
  RESIDENT_RATE = 0.10
  PRESET_MONTHLY = [ 10_000, 30_000, 50_000 ].freeze

  Instrument = Data.define(:key, :name, :kind, :max_annual, :note)
  Scenario = Data.define(:annual, :monthly, :savings, :effective_rate, :at_max)
  Result = Data.define(:instrument, :scenarios, :max_savings)

  INSTRUMENTS = [
    Instrument.new(
      key: :shokibo, name: "小規模企業共済", kind: :income_deduction, max_annual: 840_000,
      note: "掛金は全額が所得控除。受取時に退職所得等として課税される「課税の繰延べ」制度です。"
    ),
    Instrument.new(
      key: :ideco, name: "iDeCo（個人型確定拠出年金）", kind: :income_deduction, max_annual: 816_000,
      note: "第1号被保険者の上限は月6.8万円。掛金は全額所得控除ですが、原則60歳まで引き出せません。"
    ),
    Instrument.new(
      key: :sefuti, name: "経営セーフティ共済（倒産防止共済）", kind: :business_expense, max_annual: 2_400_000,
      note: "掛金は必要経費に算入（事業所得・国保も圧縮）。解約時は益金算入。40ヶ月以上の納付で全額返戻されます。"
    )
  ].freeze

  def initialize(fiscal_year, include_care: false)
    @fiscal_year = fiscal_year
    @include_care = include_care
  end

  def calculate
    {
      marginal_rate: marginal_rate,
      income_marginal_rate: baseline_income_tax[:income_tax_marginal_rate],
      taxable_income: baseline_income_tax[:taxable_income],
      results: INSTRUMENTS.map { |instrument| simulate(instrument) }
    }
  end

  private

  # Effective marginal rate on an additional 所得控除: income-tax bracket
  # (grossed up for 復興特別所得税) plus the 10% resident-tax 所得割.
  def marginal_rate
    baseline_income_tax[:income_tax_marginal_rate] * (1 + RECONSTRUCTION_RATE) + RESIDENT_RATE
  end

  def baseline_income_tax
    @baseline_income_tax ||= IncomeTaxCalculator.new(@fiscal_year).calculate
  end

  def simulate(instrument)
    baseline = burden_for(instrument, 0)
    scenarios = contribution_amounts(instrument).map do |annual|
      savings = baseline - burden_for(instrument, annual)
      Scenario.new(
        annual: annual,
        monthly: annual / 12,
        savings: savings,
        effective_rate: (savings * 100.0 / annual).round(1),
        at_max: annual == instrument.max_annual
      )
    end
    Result.new(instrument: instrument, scenarios: scenarios, max_savings: scenarios.map(&:savings).max || 0)
  end

  def contribution_amounts(instrument)
    presets = PRESET_MONTHLY.map { |monthly| monthly * 12 }.select { |annual| annual < instrument.max_annual }
    (presets + [ instrument.max_annual ]).uniq.sort
  end

  def burden_for(instrument, annual)
    if instrument.kind == :income_deduction
      burden(extra_income_deductions: annual, include_health: false)
    else
      burden(extra_business_expenses: annual, include_health: true)
    end
  end

  # Total tax burden under a hypothetical contribution. Uses pre-withholding
  # income tax (total_tax) since withholding is constant and cancels in deltas.
  def burden(extra_income_deductions: 0, extra_business_expenses: 0, include_health: false)
    income = IncomeTaxCalculator.new(
      @fiscal_year,
      extra_income_deductions: extra_income_deductions,
      extra_business_expenses: extra_business_expenses
    ).calculate
    resident = ResidentTaxEstimator.new(income, extra_income_deductions: extra_income_deductions).calculate

    total = income[:total_tax] + resident[:total]
    total += HealthInsuranceEstimator.new(income, include_care: @include_care).calculate[:total] if include_health
    total
  end
end
