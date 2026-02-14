# frozen_string_literal: true

class Expense < ApplicationRecord
  belongs_to :fiscal_year
  has_one :journal_entry, as: :source, dependent: :destroy
  has_many_attached :receipts

  after_save :sync_journal_entry
  after_destroy :destroy_journal_entry

  enum :category, {
    equipment: 0,       # 備品・器具
    office: 1,          # 事務所・コワーキング
    communication: 2,   # 通信費
    software: 3,        # ソフトウェア・サブスクリプション
    transportation: 4,  # 交通費
    books: 5,           # 書籍・学習
    other: 6            # その他
  }, default: :other

  CATEGORY_LABELS = {
    "equipment" => "備品・器具 (Equipment)",
    "office" => "事務所・コワーキング (Office)",
    "communication" => "通信費 (Communication)",
    "software" => "ソフトウェア (Software)",
    "transportation" => "交通費 (Transportation)",
    "books" => "書籍・学習 (Books/Learning)",
    "other" => "その他 (Other)"
  }.freeze

  validates :description, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :category, presence: true
  validates :business_ratio, presence: true, numericality: { in: 1..100, only_integer: true }
  validates :date, presence: true

  # Deductible amount after applying business use ratio (家事按分)
  def deductible_amount
    amount * business_ratio / 100
  end

  # Consumption tax deductible under 本則課税 (only if invoice eligible)
  def consumption_tax_deductible
    return 0 unless invoice_eligible?

    amount * 10 / 110 * business_ratio / 100
  end

  # Flag for depreciation rules (items ≥ ¥100,000)
  def high_value?
    amount >= 100_000
  end

  def category_label
    CATEGORY_LABELS[category]
  end

  private

  def sync_journal_entry
    JournalEntrySync.sync(self) if Account.any?
  end

  def destroy_journal_entry
    JournalEntrySync.destroy(self)
  end
end
