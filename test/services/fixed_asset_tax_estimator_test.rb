# frozen_string_literal: true

require "test_helper"

class FixedAssetTaxEstimatorTest < ActiveSupport::TestCase
  setup do
    @bought = FiscalYear.create!(year: 2030)
    @following = FiscalYear.create!(year: 2031)
  end

  test "an asset loses half a year's 減価率 at its first assessment, then a full year's each time" do
    # 耐用年数4年: 減価率 0.438, so 0.781 the first time and 0.562 after that.
    assert_equal 234_300, value(300_000, 4, 1) # 300,000 × 0.781
    assert_equal 131_676, value(300_000, 4, 2) # 234,300 × 0.562 = 131,676.6
    assert_equal 74_001, value(300_000, 4, 3)  # 131,676 × 0.562 = 74,001.9
    assert_equal 163_000, value(200_000, 5, 1) # 0.369 / 2 = 0.1845, published as 0.815
  end

  test "the value stops at 5% of the cost" do
    assert_equal 23_372, value(300_000, 4, 5) # 74,001 → 41,588 → 23,372
    assert_equal 15_000, value(300_000, 4, 6) # 13,135 is under 300,000 × 5%
    assert_equal 15_000, value(300_000, 4, 40)
  end

  test "the 減価率 table covers every useful life the app accepts" do
    assert_equal (2..50).to_a, FixedAssetTaxEstimator::DEPRECIATION_RATES.keys
    assert_equal [ 684, 206, 109, 45 ], FixedAssetTaxEstimator::DEPRECIATION_RATES.values_at(2, 10, 20, 50)
  end

  test "少額特例 and depreciated assets are declared; 一括償却, under-¥100,000 and software are not" do
    asset("カメラ", 350_000, :small_asset_special, useful_life: 5)
    asset("サーバー", 600_000, :normal_depreciation, useful_life: 5)
    asset("椅子", 150_000, :lump_sum_3_year)
    asset("キーボード", 50_000, :immediate_expense)
    asset("会計ソフト", 500_000, :normal_depreciation, useful_life: 5, category: :software)
    @bought.expenses.create!(description: "家賃", amount: 900_000, category: :office, date: Date.new(2030, 7, 1))

    estimate = FixedAssetTaxEstimator.new(@bought).calculate

    assert_equal %w[カメラ サーバー], estimate[:rows].map { |row| row.asset.description }
    assert_equal [ 285_250, 489_000 ], estimate[:rows].map(&:value) # × 0.815
    assert_equal 950_000, estimate[:total_cost]
    assert_equal 774_250, estimate[:total_value]
    assert_equal 774_000, estimate[:tax_base]
    assert estimate[:exempt]
    assert_equal 0, estimate[:tax]
  end

  test "at or over the 免税点 the tax is 1.4% of the 課税標準額, in hundreds of yen" do
    asset("撮影機材", 2_500_000, :normal_depreciation, useful_life: 5, business_ratio: 50)

    first = FixedAssetTaxEstimator.new(@bought).calculate
    assert_equal 2031, first[:tax_year]
    assert_equal 2_037_500, first[:total_value] # 2,500,000 × 0.815, before 家事按分
    assert_equal 2_037_000, first[:tax_base]
    assert_not first[:exempt]
    assert_equal 28_500, first[:tax] # 2,037,000 × 1.4% = 28,518

    second = FixedAssetTaxEstimator.new(@following).calculate
    assert_equal 1_285_662, second[:total_value] # 2,037,500 × 0.631 = 1,285,662.5
    assert second[:exempt]
    assert_equal 0, second[:tax]
  end

  test "the 免税点 is ¥1,800,000 from the 2027 assessment and ¥1,500,000 before" do
    assert_equal 1_500_000, FixedAssetTaxEstimator.exemption_point(2026)
    assert_equal 1_800_000, FixedAssetTaxEstimator.exemption_point(2027)

    # 2,000,000 × 0.815 = 1,630,000: taxed on January 1st 2026, exempt a year later at the same value.
    old = FiscalYear.create!(year: 2025)
    old.expenses.create!(description: "機材", amount: 2_000_000, category: :equipment, kind: :asset,
                         accounting_method: :normal_depreciation, useful_life: 5, date: Date.new(2025, 7, 1))
    assert_equal 22_800, FixedAssetTaxEstimator.new(old).calculate[:tax] # 1,630,000 × 1.4% = 22,820
  end

  test "a 少額特例 asset without a useful life is listed apart and left out of the total" do
    monitor = asset("モニター", 150_000, :small_asset_special)

    estimate = FixedAssetTaxEstimator.new(@bought).calculate

    assert_equal [ monitor ], estimate[:unvalued]
    assert_empty estimate[:rows]
    assert_equal 0, estimate[:total_value]
  end

  test "the declaration is due on January 31st, or the Monday after a weekend" do
    assert_equal Date.new(2031, 1, 31), FixedAssetTaxEstimator.new(@bought).calculate[:declare_by] # a Friday
    assert_equal Date.new(2027, 2, 1), FixedAssetTaxEstimator.new(FiscalYear.create!(year: 2026)).calculate[:declare_by]
  end

  private

  def value(cost, useful_life, years) = FixedAssetTaxEstimator.value(cost: cost, useful_life: useful_life, years: years)

  def asset(description, amount, method, **attributes)
    @bought.expenses.create!(description: description, amount: amount, category: :equipment, kind: :asset,
                             accounting_method: method, date: Date.new(2030, 7, 1), **attributes)
  end
end
