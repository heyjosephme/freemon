# frozen_string_literal: true

class FiscalYear < ApplicationRecord
  has_one :salary_income, dependent: :destroy
  has_many :revenues, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :deductions, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  enum :filing_type, { blue_65: 0, blue_10: 1, white: 2 }, default: :blue_65

  # 確定申告 deadlines (month, day) in the spring after the year ends.
  FILING_DEADLINES = { "所得税" => [ 3, 15 ], "消費税" => [ 3, 31 ] }.freeze

  validates :year, presence: true, uniqueness: true, numericality: { in: 2020..2099, only_integer: true }
  validates :filing_type, presence: true

  after_create :post_depreciation_of_earlier_assets

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

  def total_deductions_amount
    deductions.sum(:amount)
  end

  private

  # A year created after assets were bought picks up its share of their depreciation.
  def post_depreciation_of_earlier_assets
    return unless Account.any?

    Expense.depreciable.where(date: ...Date.new(year, 1, 1)).find_each { |asset| JournalEntrySync.sync(asset) }
  end
end
