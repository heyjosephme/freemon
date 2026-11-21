# frozen_string_literal: true

# 償却資産税 (固定資産税の償却資産分) 概算: the assets held on January 1st after the fiscal
# year ends, which are declared by the end of that January and taxed for that 年度.
#
# Each asset is valued from its cost (税込, before 家事按分) by 固定資産評価基準:
#   取得の翌年度     取得価額 × (1 − r/2)   half a year, whichever month it was bought
#   その後の年度     前年度の評価額 × (1 − r)
# down to 5% of the cost, where r is the 減価率 for its 耐用年数. The values add up to
# the 課税標準額 (rounded down to ¥1,000); below the 免税点 nothing is due, otherwise
# 1.4% of it (rounded down to ¥100). One municipality is assumed.
class FixedAssetTaxEstimator
  RATE_BP = 140 # 標準税率 1.4%

  # 免税点: a 課税標準額 under this is not taxed. Raised from the 令和9年度 (2027) assessment.
  EXEMPTION_POINT = 1_800_000
  EXEMPTION_POINT_BEFORE_RAISE = 1_500_000
  EXEMPTION_POINT_RAISED_IN = 2027

  MINIMUM_VALUE_PERCENT = 5

  # 耐用年数に応ずる減価率 in thousandths, for 2 to 50 years (固定資産評価基準 別表第15).
  DEPRECIATION_RATES = [
    684, 536, 438, 369, 319, 280, 250, 226, 206, 189, 175, 162, 152, 142, 134, 127, 120, 114, 109, 104, 99, 95, 92, 88, 85,
    82, 79, 76, 74, 72, 69, 67, 66, 64, 62, 60, 59, 57, 56, 55, 53, 52, 51, 50, 49, 48, 47, 46, 45
  ].each_with_index.to_h { |rate, index| [ index + 2, rate ] }.freeze

  # One asset on the declaration. `years` counts assessments so far (1 = bought last year).
  Row = Struct.new(:asset, :years, :rate, :value, keyword_init: true) do
    def floored? = value == FixedAssetTaxEstimator.minimum_value(asset.amount)
  end

  def self.minimum_value(cost) = cost * MINIMUM_VALUE_PERCENT / 100

  # 評価額 at an asset's `years`-th assessment. The published 残存率 have three decimals, so the
  # half-year rate is cut to thousandths before multiplying.
  def self.value(cost:, useful_life:, years:)
    rate = DEPRECIATION_RATES.fetch(useful_life)
    floor = minimum_value(cost)
    value = cost * ((2000 - rate) / 2) / 1000
    (years - 1).times do
      break if value <= floor

      value = value * (1000 - rate) / 1000
    end
    [ value, floor ].max
  end

  def self.exemption_point(tax_year)
    tax_year >= EXEMPTION_POINT_RAISED_IN ? EXEMPTION_POINT : EXEMPTION_POINT_BEFORE_RAISE
  end

  def initialize(fiscal_year)
    @fiscal_year = fiscal_year
    @tax_year = fiscal_year.year + 1
  end

  def calculate
    assets = Expense.fixed_asset_taxable.where(date: ..Date.new(@fiscal_year.year, 12, 31)).order(:date, :id).to_a
    valued, unvalued = assets.partition(&:useful_life)
    rows = valued.map { |asset| row(asset) }
    total_value = rows.sum(&:value)
    tax_base = total_value / 1000 * 1000
    exemption_point = self.class.exemption_point(@tax_year)
    exempt = tax_base < exemption_point

    {
      tax_year: @tax_year,
      assessed_on: Date.new(@tax_year, 1, 1),
      declare_by: declaration_deadline,
      rows: rows,
      # 少額特例 assets saved without a 耐用年数: they can't be valued, so they're left out.
      unvalued: unvalued,
      total_cost: rows.sum { |row| row.asset.amount },
      total_value: total_value,
      tax_base: tax_base,
      exemption_point: exemption_point,
      exempt: exempt,
      tax: exempt ? 0 : tax_base * RATE_BP / 10_000 / 100 * 100
    }
  end

  private

  def row(asset)
    years = @tax_year - asset.date.year
    Row.new(asset: asset, years: years, rate: DEPRECIATION_RATES.fetch(asset.useful_life),
            value: self.class.value(cost: asset.amount, useful_life: asset.useful_life, years: years))
  end

  # January 31st, or the next weekday when that falls on a weekend.
  def declaration_deadline
    deadline = Date.new(@tax_year, 1, 31)
    deadline += 1 while deadline.saturday? || deadline.sunday?
    deadline
  end
end
