# frozen_string_literal: true

class Deduction < ApplicationRecord
  belongs_to :fiscal_year

  enum :deduction_type, {
    kokumin_health: 0,   # 国民健康保険
    kokumin_pension: 1,  # 国民年金
    life_insurance: 2,   # 生命保険料控除
    medical: 3,          # 医療費控除
    furusato: 4,         # ふるさと納税（寄附金控除）
    other_deduction: 5   # その他の控除
  }

  DEDUCTION_TYPE_LABELS = {
    "kokumin_health" => "国民健康保険 (National Health Insurance)",
    "kokumin_pension" => "国民年金 (National Pension)",
    "life_insurance" => "生命保険料控除 (Life Insurance)",
    "medical" => "医療費控除 (Medical Expenses)",
    "furusato" => "ふるさと納税 (Furusato Nozei)",
    "other_deduction" => "その他 (Other)"
  }.freeze

  validates :deduction_type, presence: true
  validates :amount, presence: true, numericality: { greater_than: 0, only_integer: true }

  def deduction_type_label
    DEDUCTION_TYPE_LABELS[deduction_type]
  end
end
