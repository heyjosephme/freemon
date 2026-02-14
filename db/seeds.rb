# frozen_string_literal: true

# === Chart of Accounts (勘定科目) ===
default_accounts = [
  # 資産 (Assets)
  { code: "101", name: "現金", name_en: "Cash", account_type: :asset },
  { code: "102", name: "普通預金", name_en: "Bank Savings", account_type: :asset },
  { code: "103", name: "売掛金", name_en: "Accounts Receivable", account_type: :asset },
  { code: "190", name: "事業主貸", name_en: "Owner Drawings", account_type: :asset },

  # 負債 (Liabilities)
  { code: "201", name: "買掛金", name_en: "Accounts Payable", account_type: :liability },
  { code: "202", name: "未払金", name_en: "Accrued Expenses", account_type: :liability },
  { code: "290", name: "事業主借", name_en: "Owner Investment", account_type: :liability },

  # 収益 (Revenue)
  { code: "401", name: "売上高", name_en: "Sales", account_type: :revenue },

  # 費用 (Expenses)
  { code: "501", name: "租税公課", name_en: "Taxes & Public Charges", account_type: :expense },
  { code: "502", name: "旅費交通費", name_en: "Transportation", account_type: :expense },
  { code: "503", name: "通信費", name_en: "Communication", account_type: :expense },
  { code: "504", name: "消耗品費", name_en: "Supplies/Equipment", account_type: :expense },
  { code: "505", name: "地代家賃", name_en: "Rent", account_type: :expense },
  { code: "506", name: "水道光熱費", name_en: "Utilities", account_type: :expense },
  { code: "507", name: "新聞図書費", name_en: "Books/Subscriptions", account_type: :expense },
  { code: "508", name: "支払手数料", name_en: "Fees/Commission", account_type: :expense },
  { code: "509", name: "外注費", name_en: "Outsourcing", account_type: :expense },
  { code: "510", name: "雑費", name_en: "Miscellaneous", account_type: :expense }
]

default_accounts.each do |attrs|
  Account.find_or_create_by!(code: attrs[:code]) do |a|
    a.name = attrs[:name]
    a.name_en = attrs[:name_en]
    a.account_type = attrs[:account_type]
    a.system_default = true
  end
end

# === Sample data (development only) ===
if Rails.env.development? && FiscalYear.none?
  fy = FiscalYear.create!(year: 2025, filing_type: :blue_65)

  fy.create_salary_income!(gross_salary: 3_000_000, tax_withheld: 75_000, social_insurance: 420_000)

  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 7, 31))
  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 8, 31))
  fy.revenues.create!(client_name: "合同会社デザインラボ", amount: 220_000, date: Date.new(2025, 9, 15))
  fy.revenues.create!(client_name: "株式会社テックコープ", amount: 550_000, date: Date.new(2025, 10, 31))

  fy.expenses.create!(description: "MacBook Pro", amount: 298_000, category: :equipment, business_ratio: 80, invoice_eligible: true, date: Date.new(2025, 7, 1))
  fy.expenses.create!(description: "コワーキングスペース月額 (7-12月)", amount: 180_000, category: :office, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "インターネット回線 (年額)", amount: 72_000, category: :communication, business_ratio: 50, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "Adobe Creative Cloud", amount: 86_880, category: :software, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 12, 31))
  fy.expenses.create!(description: "技術書", amount: 12_000, category: :books, business_ratio: 100, invoice_eligible: true, date: Date.new(2025, 8, 15))
  fy.expenses.create!(description: "個人事業主カフェ作業 (レシート)", amount: 24_000, category: :other, business_ratio: 100, invoice_eligible: false, date: Date.new(2025, 12, 31))

  fy.deductions.create!(deduction_type: :kokumin_health, amount: 180_000)
  fy.deductions.create!(deduction_type: :kokumin_pension, amount: 100_200)
end
