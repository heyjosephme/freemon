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

  private

  def sync_journal_entry
    JournalEntrySync.sync(self) if Account.any?
  end

  def destroy_journal_entry
    JournalEntrySync.destroy(self)
  end
end
