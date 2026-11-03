# frozen_string_literal: true

require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @expense = FiscalYear.create!(year: 2099).expenses.create!(description: "コーヒー豆", amount: 1_200, category: :other,
                                                              date: Date.new(2099, 1, 1))
    @blue = FiscalYear.create!(year: 2030)
  end

  test "expenses default to in-person" do
    assert @expense.in_person?
    assert_equal "店頭・対面", @expense.purchase_channel_label
  end

  test "an in-person expense needs a receipt until one is attached; an online one never does" do
    assert @expense.receipt_missing?

    @expense.receipts.attach(io: StringIO.new("%PDF-1.4"), filename: "receipt.pdf", content_type: "application/pdf")
    assert_not @expense.receipt_missing?

    assert_not Expense.new(purchase_channel: :online).receipt_missing?
  end

  test "an asset without a method gets one from its amount and the filing type" do
    { 99_999 => "immediate_expense", 100_000 => "small_asset_special", 399_999 => "small_asset_special",
      400_000 => "normal_depreciation" }.each do |amount, method|
      assert_equal method, suggested_method(@blue, amount), amount
    end

    white = FiscalYear.create!(year: 2031, filing_type: :white)
    assert_equal "lump_sum_3_year", suggested_method(white, 150_000)
    assert_equal "normal_depreciation", suggested_method(white, 250_000)
  end

  test "each method only takes amounts in its range" do
    assert asset(99_999, :immediate_expense).valid?
    assert_not asset(100_000, :immediate_expense).valid?
    assert asset(100_000, :lump_sum_3_year).valid?
    assert_not asset(200_000, :lump_sum_3_year).valid?
    assert asset(399_999, :small_asset_special).valid?
    assert_not asset(400_000, :small_asset_special).valid?
    assert asset(50_000, :normal_depreciation, useful_life: 4).valid?
  end

  test "the special measure is for 青色申告 and ¥3,000,000 of assets a year" do
    white = FiscalYear.create!(year: 2031, filing_type: :white)
    plain = asset(300_000, :small_asset_special, fiscal_year: white)
    assert_not plain.valid?
    assert_match "青色申告", plain.errors[:accounting_method].first

    10.times { asset(299_000, :small_asset_special).save! } # ¥2,990,000
    over = asset(100_000, :small_asset_special)
    assert_not over.valid?
    assert_match "年300万円", over.errors[:accounting_method].first

    over.accounting_method = nil
    over.valid?
    assert_equal "lump_sum_3_year", over.accounting_method, "once the cap is used, the suggestion moves on"
  end

  test "normal depreciation needs a useful life" do
    server = asset(600_000, :normal_depreciation)
    assert_not server.valid?
    assert_match "耐用年数", server.errors[:useful_life].first
  end

  test "straight-line depreciation prorates the first year by month and leaves ¥1 on the books" do
    pc = asset(500_000, :normal_depreciation, useful_life: 4, date: Date.new(2030, 7, 15))

    assert_equal({ 2030 => 62_500, 2031 => 125_000, 2032 => 125_000, 2033 => 125_000, 2034 => 62_499 }, pc.write_off_schedule)
    assert_equal 1, pc.book_value_after(2034)
    assert_equal 334, asset(500_000, :normal_depreciation, useful_life: 3).depreciation_rate
  end

  test "lump-sum assets split evenly over three years, the remainder in the last" do
    assert_equal({ 2030 => 33_333, 2031 => 33_333, 2032 => 33_335 }, asset(100_001, :lump_sum_3_year).write_off_schedule)
  end

  test "家事按分 applies to each year's share" do
    pc = asset(500_000, :normal_depreciation, useful_life: 4, date: Date.new(2030, 7, 15), business_ratio: 80)

    assert_equal 50_000, pc.deduction_for(2030) # 62,500 × 80%
    assert_equal 100_000, pc.deduction_for(2031)
    assert_equal 0, pc.deduction_for(2035)
  end

  test "an expense saved as 経費 drops any asset settings" do
    @expense.update!(accounting_method: :normal_depreciation, useful_life: 4)

    assert_nil @expense.reload.accounting_method
    assert_nil @expense.useful_life
  end

  private

  def asset(amount, method, fiscal_year: @blue, date: Date.new(fiscal_year.year, 7, 1), **attributes)
    fiscal_year.expenses.new(description: "設備", amount: amount, category: :equipment, kind: :asset, accounting_method: method,
                             date: date, **attributes)
  end

  def suggested_method(fiscal_year, amount)
    asset(amount, nil, fiscal_year: fiscal_year).tap(&:valid?).accounting_method
  end
end
