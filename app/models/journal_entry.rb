# frozen_string_literal: true

class JournalEntry < ApplicationRecord
  belongs_to :fiscal_year
  belongs_to :source, polymorphic: true, optional: true
  has_many :lines, class_name: "JournalEntryLine", dependent: :destroy

  accepts_nested_attributes_for :lines, allow_destroy: true, reject_if: :all_blank

  validates :date, presence: true
  validates :description, presence: true
  validate :debits_equal_credits, if: -> { lines.any? }

  scope :chronological, -> { order(:date, :created_at) }

  def manual?
    source_type.nil?
  end

  def total_debits
    lines.select(&:debit?).sum(&:amount)
  end

  def total_credits
    lines.select(&:credit?).sum(&:amount)
  end

  def debit_lines
    lines.select(&:debit?)
  end

  def credit_lines
    lines.select(&:credit?)
  end

  private

  def debits_equal_credits
    if total_debits != total_credits
      errors.add(:base, "借方合計と貸方合計が一致しません (Debits must equal credits)")
    end
  end
end
