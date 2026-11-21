# frozen_string_literal: true

class FiscalYear < ApplicationRecord
  has_one :salary_income, dependent: :destroy
  has_many :revenues, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :deductions, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  enum :filing_type, { blue_65: 0, blue_10: 1, white: 2 }, default: :blue_65

  # When this year's 消費税 becomes 租税公課 (税込経理方式): accrued at year-end as 未払金,
  # or in the following year, when it's paid.
  enum :consumption_tax_timing, { accrued: 0, when_paid: 1 }, prefix: :consumption_tax, default: :accrued

  CONSUMPTION_TAX_TIMING_LABELS = {
    "accrued" => "未払計上（この年の経費）",
    "when_paid" => "納付時（翌年の経費）"
  }.freeze

  # 確定申告 deadlines (month, day) in the spring after the year ends.
  FILING_DEADLINES = { "所得税" => [ 3, 15 ], "消費税" => [ 3, 31 ] }.freeze

  validates :year, presence: true, uniqueness: true, numericality: { in: 2020..2099, only_integer: true }
  validates :filing_type, presence: true
  # Optional: the year's goal for #business_profit.
  validates :business_profit_target, numericality: { only_integer: true, greater_than: 0 }, allow_nil: true

  after_create :post_depreciation_of_earlier_assets
  after_save :sync_consumption_tax_entries
  after_destroy { JournalEntrySync.destroy(self) }

  # A 個人事業主's accounting period is the calendar year.
  def self.current_year = Date.current.year

  def self.latest = order(year: :desc).first

  # Where the home page lands: this year, else the most recent earlier year, else the latest.
  def self.home
    find_by(year: current_year) || where(year: ...current_year).order(year: :desc).first || latest
  end

  # The year the create form suggests: this year until it exists, then the
  # most recent earlier year without a record.
  def self.suggested_new_year
    taken = pluck(:year)
    year = current_year
    year -= 1 while taken.include?(year)
    year
  end

  # New entries start on today's date in the current year, else on January 1st.
  def default_entry_date = year == self.class.current_year ? Date.current : Date.new(year, 1, 1)

  # Deadlines for this year's return that are still ahead, during the
  # January–March after the year ends. Empty at any other time.
  def open_filing_deadlines(today = Date.current)
    return {} unless today.year == year + 1

    FILING_DEADLINES
      .transform_values { |month, day| Date.new(year + 1, month, day) }
      .select { |_tax, deadline| today <= deadline }
  end

  def filing_type_label
    case filing_type
    when "blue_65" then "青色申告 65万円控除"
    when "blue_10" then "青色申告 10万円控除"
    when "white" then "白色申告"
    end
  end

  def total_revenue
    revenues.sum(:amount)
  end

  def blue? = !white?

  # Business expenses deductible this year (家事按分後): what was paid this year, except that
  # lump-sum and depreciated assets count only this year's share, wherever they were bought.
  def total_expenses
    expenses.written_off_when_paid.sum("amount * business_ratio / 100") + depreciation_total
  end

  # This year's share of lump-sum and depreciated assets (家事按分後), including earlier years' purchases.
  def depreciation_total = depreciable_assets.sum { |asset| asset.deduction_for(year) }

  # Lump-sum and depreciated assets with a share in this year, bought this year or before.
  def depreciable_assets
    Expense.depreciable.where(date: ..Date.new(year, 12, 31)).order(:date, :id).select { |asset| asset.write_off_schedule.key?(year) }
  end

  # The rows of this year's 減価償却費の計算: lump-sum and depreciated assets with a share this
  # year, plus this year's 少額減価償却資産の特例 purchases.
  def depreciation_table_assets
    (depreciable_assets + expenses.small_asset_special.to_a).sort_by { |asset| [ asset.date, asset.id ] }
  end

  # This year's purchases under the 少額減価償却資産の特例, which allows ¥3,000,000 a year.
  def small_asset_special_total(except: nil)
    expenses.small_asset_special.where.not(id: except&.id).sum(:amount)
  end

  # The 消費税 this year's sales and purchases give rise to (cheapest method, as on the reserve page).
  def consumption_tax_payable = ConsumptionTaxCalculator.new(self).calculate[:payable]

  # 消費税 deductible this year as 租税公課: this year's own when accrued, plus last year's
  # when that year expenses it on payment. Each year's tax is deducted exactly once.
  def consumption_tax_expense
    (consumption_tax_accrued? ? consumption_tax_payable : 0) + consumption_tax_carried_in
  end

  # Last year's 消費税, when it's expensed this year on payment.
  def consumption_tax_carried_in
    previous = previous_year
    previous&.consumption_tax_when_paid? ? previous.consumption_tax_payable : 0
  end

  def previous_year = self.class.find_by(year: year - 1)

  def following_year = self.class.find_by(year: year + 1)

  # 売上 − 経費（按分後）, before 消費税（租税公課）and 青色申告特別控除. Negative in a loss.
  # The dashboard's figure; the tax calculation takes #consumption_tax_expense off as well.
  def business_profit = total_revenue - total_expenses

  # How far #business_profit is towards the target, as a whole percent rounded down
  # (so 100 means reached). 0 in a loss; nil without a target.
  def business_profit_progress(profit = business_profit)
    [ profit, 0 ].max * 100 / business_profit_target if business_profit_target
  end

  def total_deductions_amount
    deductions.sum(:amount)
  end

  private

  # Reposts the 消費税 entries of this year and of last year (whose payment lands in this one).
  def sync_consumption_tax_entries
    return unless Account.any?

    [ previous_year, self ].compact.each { |fiscal_year| JournalEntrySync.sync(fiscal_year) }
  end

  # A year created after assets were bought picks up its share of their depreciation.
  def post_depreciation_of_earlier_assets
    return unless Account.any?

    Expense.depreciable.where(date: ...Date.new(year, 1, 1)).find_each { |asset| JournalEntrySync.sync(asset) }
  end
end
