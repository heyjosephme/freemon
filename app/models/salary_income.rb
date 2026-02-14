# frozen_string_literal: true

class SalaryIncome < ApplicationRecord
  DEDUCTION_BRACKETS = [
    { limit: 1_625_000,    deduction: ->(_s) { 550_000 } },
    { limit: 1_800_000,    deduction: ->(s) { (s * 0.4 - 100_000).to_i } },
    { limit: 3_600_000,    deduction: ->(s) { (s * 0.3 + 80_000).to_i } },
    { limit: 6_600_000,    deduction: ->(s) { (s * 0.2 + 440_000).to_i } },
    { limit: 8_500_000,    deduction: ->(s) { (s * 0.1 + 1_100_000).to_i } },
    { limit: Float::INFINITY, deduction: ->(_s) { 1_950_000 } }
  ].freeze

  belongs_to :fiscal_year

  validates :gross_salary, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :tax_withheld, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }
  validates :social_insurance, presence: true, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # 給与所得控除
  def salary_deduction
    return 0 if gross_salary <= 0

    bracket = DEDUCTION_BRACKETS.find { |b| gross_salary <= b[:limit] }
    bracket[:deduction].call(gross_salary)
  end

  # 給与所得 (salary income after deduction)
  def salary_income_amount
    [ gross_salary - salary_deduction, 0 ].max
  end
end
