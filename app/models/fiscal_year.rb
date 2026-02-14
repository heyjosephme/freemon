# frozen_string_literal: true

class FiscalYear < ApplicationRecord
  has_one :salary_income, dependent: :destroy
  has_many :revenues, dependent: :destroy
  has_many :expenses, dependent: :destroy
  has_many :deductions, dependent: :destroy
  has_many :journal_entries, dependent: :destroy

  enum :filing_type, { blue_65: 0, blue_10: 1, white: 2 }, default: :blue_65

  validates :year, presence: true, uniqueness: true, numericality: { in: 2020..2099, only_integer: true }
  validates :filing_type, presence: true

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

  def total_expenses
    expenses.sum("amount * business_ratio / 100")
  end

  def total_deductions_amount
    deductions.sum(:amount)
  end
end
