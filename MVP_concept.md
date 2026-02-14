# Prompt: Japanese Freelancer Tax Calculator Web App

Build a single-page React web app (TypeScript + Tailwind CSS) that helps a freelancer in Japan calculate and organize their tax filing for a fiscal year where they worked as both a **個人事業主 (sole proprietor)** and a **契約社員 (contract employee)**.

## Context & Tax Rules

The user has:
- **Blue-form filing (青色申告)** status with invoice registration (インボイス番号)
- Part of the year as a sole proprietor (事業所得) and part as a contract employee (給与所得)
- Total business revenue under ¥1,000,000
- Business expenses that may exceed business revenue (legitimate startup/equipment costs)

### Key Japanese tax concepts to implement:

1. **Income Tax (所得税) - 確定申告**
   - Combine 給与所得 (salary income from 源泉徴収票) and 事業所得 (business income)
   - Apply 青色申告特別控除 (Blue form special deduction): ¥650,000 max (for e-Tax + double-entry bookkeeping)
   - If business income is negative (赤字), allow 損益通算: offset the loss against salary income
   - Apply standard deductions: 基礎控除 (¥480,000), 社会保険料控除 (user inputs total)
   - Calculate progressive income tax using Japan's tax brackets:
     - ¥1 ~ ¥1,950,000: 5%
     - ¥1,950,001 ~ ¥3,300,000: 10% (deduct ¥97,500)
     - ¥3,300,001 ~ ¥6,950,000: 20% (deduct ¥427,500)
     - ¥6,950,001 ~ ¥9,000,000: 23% (deduct ¥636,000)
     - ¥9,000,001 ~ ¥18,000,000: 33% (deduct ¥1,536,000)
     - ¥18,000,001 ~ ¥40,000,000: 40% (deduct ¥2,796,000)
     - ¥40,000,001+: 45% (deduct ¥4,796,000)
   - Add 復興特別所得税: 2.1% of calculated income tax
   - Subtract 源泉徴収税額 (tax already withheld by employer) to get final amount owed or refund

2. **Consumption Tax (消費税)**
   - The user is a 課税事業者 due to invoice registration
   - Implement THREE calculation methods and compare them:
     - **本則課税 (Standard)**: Output consumption tax collected − Input consumption tax paid (can result in REFUND if expenses > revenue)
     - **簡易課税 (Simplified)**: Output tax × (1 − 50%) [IT/services = Type 5, みなし仕入率 50%]
     - **2割特例 (20% Special Rule)**: Output tax × 20% (available until 2026 for small businesses newly registered for invoice)
   - Highlight which method is most advantageous
   - If 本則課税 results in a negative number, clearly show this as a REFUND

3. **Expense Management (経費)**
   - Allow adding individual expense items with:
     - Description
     - Amount (税込 / tax-included)
     - Category (equipment, office/coworking, communication, software/subscriptions, transportation, books/learning, other)
     - 家事按分 ratio (business use percentage, default 100%)
     - Whether the vendor has an invoice number (インボイス対応: yes/no) — only expenses with invoice can count for consumption tax deduction under 本則課税
   - For equipment over ¥100,000: flag that depreciation rules may apply, but note that items under ¥300,000 can be fully expensed under 少額減価償却資産の特例 (blue form filers)
   - Auto-calculate the consumption tax component of each expense (amount × 10/110 × 家事按分率)

## UI Requirements

### Input Sections (use a step-by-step wizard or tabbed layout):

**Step 1: Basic Info**
- Fiscal year (default: current year - 1)
- Filing type: 青色申告 (default checked, with 65万 or 10万 deduction option)

**Step 2: Salary Income (給与所得)**
- Gross salary (支払金額) from 源泉徴収票
- Income tax already withheld (源泉徴収税額)
- Social insurance premiums paid (社会保険料)
- Note: 給与所得控除 is auto-calculated using the standard table:
  - Up to ¥1,625,000: ¥550,000
  - ¥1,625,001 ~ ¥1,800,000: income × 40% − ¥100,000
  - ¥1,800,001 ~ ¥3,600,000: income × 30% + ¥80,000
  - ¥3,600,001 ~ ¥6,600,000: income × 20% + ¥440,000
  - ¥6,600,001 ~ ¥8,500,000: income × 10% + ¥1,100,000
  - ¥8,500,001+: ¥1,950,000

**Step 3: Business Income (事業所得)**
- Invoice registration date (to determine which period's revenue counts for consumption tax)
- Total business revenue (税込)
- Expense entry table (as described above)

**Step 4: Additional Deductions (所得控除)**
- 基礎控除: ¥480,000 (auto-filled)
- 社会保険料控除: pre-filled from Step 2, allow adding 国民健康保険 + 国民年金 from sole proprietor period
- Optional: 生命保険料控除, 医療費控除, ふるさと納税 (寄附金控除)

### Output / Results Dashboard:

**Income Tax Summary**
- 給与所得 calculation breakdown
- 事業所得 calculation breakdown (revenue − expenses − 青色申告控除)
- 損益通算 result if applicable
- Total 所得控除
- Taxable income (課税所得)
- Income tax amount + 復興特別所得税
- Tax already paid (源泉徴収)
- **Final: amount to pay or refund** (big, color-coded: red for pay, green for refund)

**Consumption Tax Comparison**
- Side-by-side comparison of all 3 methods
- Recommended method highlighted
- Clear indication if 本則課税 results in a refund

**Expense Summary**
- Total expenses by category (pie chart or bar chart)
- Total deductible consumption tax (for 本則課税)

## Technical Requirements

- React + TypeScript + Tailwind CSS
- All calculations client-side (no backend needed)
- Use recharts for any charts/visualizations
- Responsive design (mobile-friendly)
- All labels bilingual: Japanese primary with English in parentheses where helpful
- Currency formatted as ¥ with comma separators
- Include a "Reset All" button and ability to save/load data to localStorage
- Add tooltips or info icons explaining key tax concepts

## Important Notes

- This is a calculator/simulator tool, NOT official tax filing software
- Add a disclaimer at the top: "This is a tax simulation tool for reference only. Please consult a tax professional (税理士) for official filing."
- All amounts should be in Japanese Yen
- The app should be usable by someone with basic understanding of Japanese tax system
