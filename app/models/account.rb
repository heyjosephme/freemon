# frozen_string_literal: true

class Account < ApplicationRecord
  enum :account_type, {
    asset: 0,      # 資産
    liability: 1,  # 負債
    equity: 2,     # 資本
    revenue: 3,    # 収益
    expense: 4     # 費用
  }

  ACCOUNT_TYPE_LABELS = {
    "asset" => "資産 (Assets)",
    "liability" => "負債 (Liabilities)",
    "equity" => "資本 (Equity)",
    "revenue" => "収益 (Revenue)",
    "expense" => "費用 (Expenses)"
  }.freeze

  has_many :journal_entry_lines, dependent: :restrict_with_error

  validates :code, presence: true, uniqueness: true
  validates :name, presence: true
  validates :account_type, presence: true

  scope :ordered, -> { order(:code) }
  scope :by_type, ->(type) { where(account_type: type).order(:code) }

  def display_name
    "#{code} #{name}"
  end

  def display_name_with_en
    name_en.present? ? "#{code} #{name} (#{name_en})" : display_name
  end

  # Normal balance side: assets/expenses are debit-normal, liabilities/equity/revenue are credit-normal
  def debit_normal?
    asset? || expense?
  end

  def account_type_label
    ACCOUNT_TYPE_LABELS[account_type]
  end
end
