# frozen_string_literal: true

class JournalEntryLine < ApplicationRecord
  belongs_to :journal_entry
  belongs_to :account

  enum :side, { debit: 0, credit: 1 }

  validates :side, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }
end
