# frozen_string_literal: true

# Sample data for a freelancer who worked as both employee and sole proprietor in 2025

fy = FiscalYear.find_or_create_by!(year: 2025) do |f|
  f.filing_type = :blue_65
end

# Salary from contract employment (Jan-Jun)
fy.salary_income || fy.create_salary_income!(
  gross_salary: 3_000_000,
  tax_withheld: 75_000,
  social_insurance: 420_000
)

# Business revenue from freelance work (Jul-Dec)
if fy.revenues.empty?
  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 7, 31))
  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 8, 31))
  fy.revenues.create!(client_name: "合同会社デザインラボ", amount: 220_000, date: Date.new(2025, 9, 15))
  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 10, 31))
end

# Business expenses
if fy.expenses.empty?
  fy.expenses.create!(description: "MacBook Pro", amount: 298_000, category: :equipment, business_ratio: 80, invoice_eligible: true, date: Date.new(2025, 7, 1))
  fy.expenses.create!(description: "コワーキングスペース月額 (7-12月)", amount: 180_000, category: :office, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "インターネット回線 (年額)", amount: 72_000, category: :communication, business_ratio: 50, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "Adobe Creative Cloud", amount: 86_880, category: :software, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "技術書", amount: 12_000, category: :books, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 8, 15))
  fy.expenses.create!(description: "個人事業主カフェ作業 (レシート)", amount: 24_000, category: :other, business_ratio: 100, invoice_eligible: false, date: Date.new(2025, 12, 31))
end

# Additional deductions
if fy.deductions.empty?
  fy.deductions.create!(deduction_type: :kokumin_health, amount: 180_000)
  fy.deductions.create!(deduction_type: :kokumin_pension, amount: 100_200)
end
