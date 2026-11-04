# frozen_string_literal: true

class Revenue < ApplicationRecord
  belongs_to :fiscal_year
  has_one :journal_entry, as: :source, dependent: :destroy
  has_many_attached :invoices

  after_save :sync_journal_entry
  after_destroy :destroy_journal_entry

  validates :client_name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :date, presence: true

  # Extract consumption tax from tax-included amount
  def consumption_tax_component
    amount * 10 / 110
  end

  # 複製 dates its copy a month later; a month-end date stays at month-end (9/30 → 10/31).
  def next_month_date = date == date.end_of_month ? date.next_month.end_of_month : date.next_month

  # The fiscal year the copy belongs in, or nil until that year has been started.
  def next_month_fiscal_year
    year = next_month_date.year
    year == fiscal_year.year ? fiscal_year : FiscalYear.find_by(year:)
  end

  private

  def sync_journal_entry
    JournalEntrySync.sync(self) if Account.any?
  end

  def destroy_journal_entry
    JournalEntrySync.destroy(self)
  end
end
