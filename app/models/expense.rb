# frozen_string_literal: true

class Expense < ApplicationRecord
  belongs_to :fiscal_year
  # One entry, or for assets spread over years, one when bought plus one per year.
  has_many :journal_entries, as: :source, dependent: :destroy
  has_many_attached :receipts

  after_save :sync_journal_entry
  after_destroy :destroy_journal_entry

  enum :category, {
    equipment: 0,       # 備品・器具
    office: 1,          # 家賃・事務所 (地代家賃)
    communication: 2,   # 通信費
    software: 3,        # ソフトウェア・サブスクリプション
    transportation: 4,  # 交通費
    books: 5,           # 書籍・学習
    other: 6,           # その他
    utilities: 7        # 水道光熱費
  }, default: :other

  # Where it was bought. Online purchases get an e-receipt by email, so only
  # in-person ones need a photo of the paper receipt.
  enum :purchase_channel, { in_person: 0, online: 1 }, default: :in_person

  # 経費 is deducted in the year it's paid; 設備・資産 follows its accounting method.
  enum :kind, { ordinary: 0, asset: 1 }, default: :ordinary

  # How an asset's cost becomes 必要経費 (amounts are tax-included, 税込経理):
  #   immediate_expense    under ¥100,000: in full when bought (少額の減価償却資産)
  #   lump_sum_3_year      ¥100,000 to under ¥200,000: a third a year for three years (一括償却資産)
  #   small_asset_special  ¥100,000 to under ¥400,000: in full when bought; 青色申告 only, up to
  #                        ¥3,000,000 of assets a year (少額減価償却資産の特例)
  #   normal_depreciation  straight line over its useful life (定額法), the first year by month
  enum :accounting_method, { immediate_expense: 0, lump_sum_3_year: 1, small_asset_special: 2, normal_depreciation: 3 }

  IMMEDIATE_LIMIT = 100_000
  LUMP_SUM_LIMIT = 200_000
  SMALL_ASSET_LIMIT = 400_000
  SMALL_ASSET_ANNUAL_CAP = 3_000_000

  PURCHASE_CHANNEL_LABELS = {
    "in_person" => "店頭・対面",
    "online" => "オンライン"
  }.freeze

  KIND_LABELS = {
    "ordinary" => "経費",
    "asset" => "設備・資産"
  }.freeze

  ACCOUNTING_METHOD_LABELS = {
    "immediate_expense" => "少額の減価償却資産（10万円未満・全額経費）",
    "lump_sum_3_year" => "一括償却資産（10〜20万円未満・3年均等）",
    "small_asset_special" => "少額減価償却資産の特例（40万円未満・全額経費・青色）",
    "normal_depreciation" => "通常の減価償却（定額法）"
  }.freeze

  # In the order forms list them.
  CATEGORY_LABELS = {
    "equipment" => "備品・器具 (Equipment)",
    "office" => "家賃・事務所 (Rent/Office)",
    "utilities" => "水道光熱費 (Utilities)",
    "communication" => "通信費 (Communication)",
    "software" => "ソフトウェア (Software)",
    "transportation" => "交通費 (Transportation)",
    "books" => "書籍・学習 (Books/Learning)",
    "other" => "その他 (Other)"
  }.freeze

  # Assets whose cost is spread over later years rather than deducted when bought.
  scope :depreciable, -> { asset.where(accounting_method: [ :lump_sum_3_year, :normal_depreciation ]) }
  scope :written_off_when_paid, -> { where(accounting_method: [ nil, :immediate_expense, :small_asset_special ]) }

  before_validation :settle_asset_fields

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :category, presence: true
  validates :business_ratio, presence: true, numericality: { in: 1..100, only_integer: true }
  validates :date, presence: true
  validate :accounting_method_fits, if: :asset?

  # Deductible amount after applying business use ratio (家事按分)
  def deductible_amount
    amount * business_ratio / 100
  end

  # Consumption tax deductible under 本則課税 (only if invoice eligible)
  def consumption_tax_deductible
    return 0 unless invoice_eligible?

    amount * 10 / 110 * business_ratio / 100
  end

  # ¥100,000 or more: worth recording as 設備・資産 if it's equipment.
  def high_value?
    amount >= IMMEDIATE_LIMIT
  end

  def category_label
    CATEGORY_LABELS[category]
  end

  # The Japanese part of a category's label, e.g. "備品・器具".
  def self.category_name(category) = CATEGORY_LABELS.fetch(category).sub(/ \(.*\)\z/, "")

  def purchase_channel_label
    PURCHASE_CHANNEL_LABELS[purchase_channel]
  end

  # Paid in person but no photo of the paper receipt attached yet.
  def receipt_missing?
    in_person? && !receipts.attached?
  end

  def depreciable? = lump_sum_3_year? || normal_depreciation?

  # A short note for lists, e.g. "資産・定額法4年".
  def asset_summary
    return unless asset?

    method = { "immediate_expense" => "全額経費", "lump_sum_3_year" => "一括償却3年",
               "small_asset_special" => "少額特例", "normal_depreciation" => "定額法#{useful_life}年" }[accounting_method]
    "資産・#{method}"
  end

  # The cost that becomes 必要経費 each year, before 家事按分: all of it in the
  # year it's paid, except for lump-sum and depreciated assets.
  def write_off_schedule
    return { date.year => amount } unless depreciable?

    lump_sum_3_year? ? lump_sum_schedule : straight_line_schedule
  end

  # This expense's 必要経費 for the given year, after 家事按分.
  def deduction_for(year) = write_off_schedule.fetch(year, 0) * business_ratio / 100

  # What it deducts in its own fiscal year, matching FiscalYear#total_expenses.
  def deduction_this_year = depreciable? ? deduction_for(fiscal_year.year) : deductible_amount

  # 定額法の償却率 in thousandths: 1/耐用年数 rounded up (4年 → 250, 3年 → 334).
  def depreciation_rate = (1000 + useful_life - 1) / useful_life

  # What's left on the books at the end of the year (未償却残高).
  def book_value_after(year) = amount - write_off_schedule.select { |y, _| y <= year }.values.sum

  # Months of straight-line depreciation in the year: from the month bought, then 12 a year.
  def months_in_service(year) = year == date.year ? 13 - date.month : 12

  private

  def settle_asset_fields
    if ordinary?
      self.accounting_method = nil
    elsif accounting_method.nil? && amount.present?
      self.accounting_method = suggested_accounting_method
    end
    self.useful_life = nil unless normal_depreciation?
  end

  def suggested_accounting_method
    if amount < IMMEDIATE_LIMIT then :immediate_expense
    elsif amount < SMALL_ASSET_LIMIT && fiscal_year&.blue? && amount <= small_asset_room then :small_asset_special
    elsif amount < LUMP_SUM_LIMIT then :lump_sum_3_year
    else :normal_depreciation
    end
  end

  # What's left this year under the special measure's ¥3,000,000 cap, not counting this expense.
  def small_asset_room
    SMALL_ASSET_ANNUAL_CAP - fiscal_year.expenses.small_asset_special.where.not(id: id).sum(:amount)
  end

  def accounting_method_fits
    if accounting_method.nil?
      errors.add(:accounting_method, "償却方法を選んでください")
      return
    end
    return if amount.blank?

    case accounting_method
    when "immediate_expense"
      errors.add(:accounting_method, "全額経費（少額の減価償却資産）は10万円未満の資産だけです") unless amount < IMMEDIATE_LIMIT
    when "lump_sum_3_year"
      errors.add(:accounting_method, "一括償却資産は10万円以上20万円未満の資産だけです") unless amount.in?(IMMEDIATE_LIMIT...LUMP_SUM_LIMIT)
    when "small_asset_special"
      if !amount.in?(IMMEDIATE_LIMIT...SMALL_ASSET_LIMIT)
        errors.add(:accounting_method, "少額減価償却資産の特例は10万円以上40万円未満の資産だけです")
      elsif !fiscal_year&.blue?
        errors.add(:accounting_method, "少額減価償却資産の特例は青色申告だけで使えます")
      elsif amount > small_asset_room
        errors.add(:accounting_method, "少額減価償却資産の特例は年300万円までです（この年の残り ¥#{small_asset_room.to_fs(:delimited)}）")
      end
    when "normal_depreciation"
      errors.add(:useful_life, "耐用年数を2〜50年で入力してください（例: パソコン 4年）") unless useful_life.to_i.between?(2, 50)
    end
  end

  def lump_sum_schedule
    third = amount / 3
    { date.year => third, date.year + 1 => third, date.year + 2 => amount - third * 2 }
  end

  # The first year counts months from the month it was bought; ¥1 stays on the books (備忘価額).
  def straight_line_schedule
    full_year = [ amount * depreciation_rate / 1000, 1 ].max
    charge = amount * depreciation_rate * (13 - date.month) / 12_000
    remaining = amount - 1
    year = date.year
    schedule = {}
    while remaining.positive?
      charge = charge.clamp(1, remaining)
      schedule[year] = charge
      remaining -= charge
      year += 1
      charge = full_year
    end
    schedule
  end

  def sync_journal_entry
    JournalEntrySync.sync(self) if Account.any?
  end

  def destroy_journal_entry
    JournalEntrySync.destroy(self)
  end
end
