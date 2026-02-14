# frozen_string_literal: true

class Revenue < ApplicationRecord
  belongs_to :fiscal_year

  validates :client_name, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }
  validates :date, presence: true

  # Extract consumption tax from tax-included amount
  def consumption_tax_component
    amount * 10 / 110
  end
end
