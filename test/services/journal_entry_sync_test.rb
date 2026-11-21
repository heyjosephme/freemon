# frozen_string_literal: true

require "test_helper"

class JournalEntrySyncTest < ActiveSupport::TestCase
  setup do
    load Rails.root.join("db/seeds.rb") # the chart of accounts; sample data is development-only
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "an expense posts its business share to its category's account and the rest to 事業主貸" do
    expense = create_expense(amount: 10_000, business_ratio: 80)

    assert_equal [ [ "debit", "雑費", 8_000 ], [ "debit", "事業主貸", 2_000 ], [ "credit", "普通預金", 10_000 ] ],
                 lines(expense.journal_entries.sole)
  end

  test "水道光熱費 posts to its own account" do
    bill = create_expense(amount: 9_000, category: :utilities, business_ratio: 30)

    assert_equal [ [ "debit", "事業主貸", 6_300 ], [ "debit", "水道光熱費", 2_700 ], [ "credit", "普通預金", 9_000 ] ],
                 lines(bill.journal_entries.sole)
  end

  test "接待交際費 posts to its own account" do
    gift = create_expense(amount: 453_800, category: :entertainment)

    assert_equal [ [ "debit", "接待交際費", 453_800 ], [ "credit", "普通預金", 453_800 ] ], lines(gift.journal_entries.sole)
  end

  test "a 少額特例 asset is written off as 減価償却費 when bought" do
    asset = create_expense(amount: 300_000, kind: :asset, accounting_method: :small_asset_special)

    assert_equal [ [ "debit", "減価償却費", 300_000 ], [ "credit", "普通預金", 300_000 ] ], lines(asset.journal_entries.sole)
  end

  test "a depreciated asset is bought into 工具器具備品, then depreciated in each year, including years created later" do
    pc = create_expense(amount: 500_000, kind: :asset, accounting_method: :normal_depreciation, useful_life: 4,
                        business_ratio: 80, date: Date.new(2030, 7, 15))

    bought, depreciated = pc.journal_entries.order(:date)
    assert_equal [ [ "debit", "工具器具備品", 500_000 ], [ "credit", "普通預金", 500_000 ] ], lines(bought)
    assert_equal Date.new(2030, 12, 31), depreciated.date
    assert_equal [ [ "debit", "減価償却費", 50_000 ], [ "debit", "事業主貸", 12_500 ], [ "credit", "工具器具備品", 62_500 ] ],
                 lines(depreciated)
    assert_equal 2, pc.journal_entries.count, "no entries yet for years that don't exist"

    following = FiscalYear.create!(year: 2031)
    assert_equal [ [ "debit", "減価償却費", 100_000 ], [ "debit", "事業主貸", 25_000 ], [ "credit", "工具器具備品", 125_000 ] ],
                 lines(following.journal_entries.find_by!(source: pc))
  end

  test "accrued 消費税 posts 租税公課 against 未払金 at year-end and follows the year's sales" do
    revenue = @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))

    accrual = JournalEntry.where(source: @fiscal_year).sole
    assert_equal Date.new(2030, 12, 31), accrual.date
    assert_equal [ [ "debit", "租税公課", 20_000 ], [ "credit", "未払金", 20_000 ] ], lines(accrual) # 100,000 × 20%

    revenue.update!(amount: 2_200_000)
    assert_equal [ [ "debit", "租税公課", 40_000 ], [ "credit", "未払金", 40_000 ] ], lines(JournalEntry.where(source: @fiscal_year).sole)

    revenue.destroy!
    assert_empty JournalEntry.where(source: @fiscal_year)
  end

  test "the accrued 消費税 is settled from the bank on 3/31 once the following year exists" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))
    following = FiscalYear.create!(year: 2031)

    payment = following.journal_entries.find_by!(source: @fiscal_year)
    assert_equal Date.new(2031, 3, 31), payment.date
    assert_equal [ [ "debit", "未払金", 20_000 ], [ "credit", "普通預金", 20_000 ] ], lines(payment)
    assert_equal 2, JournalEntry.where(source: @fiscal_year).count
  end

  test "switching to 納付時 moves the 租税公課 into the following year" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))
    following = FiscalYear.create!(year: 2031)

    @fiscal_year.update!(consumption_tax_timing: :when_paid)

    payment = JournalEntry.where(source: @fiscal_year).sole
    assert_equal following, payment.fiscal_year
    assert_equal [ [ "debit", "租税公課", 20_000 ], [ "credit", "普通預金", 20_000 ] ], lines(payment)

    @fiscal_year.update!(consumption_tax_timing: :accrued)
    assert_equal [ @fiscal_year, following ], JournalEntry.where(source: @fiscal_year).order(:date).map(&:fiscal_year)
  end

  test "deleting a year removes its 消費税 payment from the following year" do
    @fiscal_year.revenues.create!(client_name: "取引先", amount: 1_100_000, date: Date.new(2030, 6, 1))
    FiscalYear.create!(year: 2031)

    @fiscal_year.destroy!
    assert_empty JournalEntry.where(source_type: "FiscalYear")
  end

  test "lump-sum assets post to 一括償却資産 and software to ソフトウェア" do
    lump = create_expense(amount: 150_000, kind: :asset, accounting_method: :lump_sum_3_year)
    software = create_expense(amount: 500_000, category: :software, kind: :asset, accounting_method: :normal_depreciation, useful_life: 5)

    assert_equal "一括償却資産", purchase_account(lump)
    assert_equal "ソフトウェア", purchase_account(software)
  end

  test "deleting an asset removes its entries in every year" do
    FiscalYear.create!(year: 2031)
    pc = create_expense(amount: 500_000, kind: :asset, accounting_method: :normal_depreciation, useful_life: 4)

    assert_difference -> { JournalEntry.count }, -3 do
      pc.destroy
    end
  end

  private

  def create_expense(**attributes)
    @fiscal_year.expenses.create!({ description: "設備", amount: 10_000, category: :other, date: Date.new(2030, 7, 1) }.merge(attributes))
  end

  # Debits first, larger amounts first.
  def lines(entry)
    entry.lines.includes(:account).sort_by { |line| [ line.credit? ? 1 : 0, -line.amount ] }.map { |line| [ line.side, line.account.name, line.amount ] }
  end

  def purchase_account(asset)
    asset.journal_entries.order(:date).first.lines.find(&:debit?).account.name
  end
end
