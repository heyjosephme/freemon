# frozen_string_literal: true

class Views::FiscalYears::TaxSummary < Views::Base
  METHOD_LABELS = {
    standard: "本則課税 (Standard)",
    simplified: "簡易課税 (Simplified)",
    special: "2割特例 (20% Special)"
  }.freeze

  def initialize(fiscal_year:, income_tax:, consumption_tax:)
    @fiscal_year = fiscal_year
    @it = income_tax
    @ct = consumption_tax
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 税額計算結果", back_path: fiscal_year_path(@fiscal_year))
    render Disclaimer.new

    # Final result card at top
    final_result_card

    # Income tax breakdown
    div(class: "mt-6") { income_tax_section }

    # Consumption tax comparison
    div(class: "mt-6") { consumption_tax_section }
  end

  private

  def final_result_card
    render Card.new do
      div(class: "text-center") do
        h2(class: "text-lg font-semibold text-gray-700 mb-2") { "所得税 最終結果 (Income Tax Result)" }
        if @it[:final_tax] > 0
          p(class: "text-3xl font-bold text-red-600") { "納付: #{format_money(@it[:final_tax])}" }
          p(class: "text-sm text-gray-500 mt-1") { "Amount to pay" }
        elsif @it[:final_tax] < 0
          p(class: "text-3xl font-bold text-green-600") { "還付: #{format_money(-@it[:final_tax])}" }
          p(class: "text-sm text-gray-500 mt-1") { "Refund" }
        else
          p(class: "text-3xl font-bold text-gray-600") { "¥0" }
          p(class: "text-sm text-gray-500 mt-1") { "Even" }
        end
      end
    end
  end

  def income_tax_section
    render Card.new(title: "所得税の計算 (Income Tax Calculation)") do
      # Salary income
      h3(class: "text-sm font-semibold text-gray-500 uppercase mb-2") { "給与所得 (Salary Income)" }
      render SummaryRow.new(label: "支払金額 (Gross)") { render MoneyDisplay.new(amount: @it[:gross_salary]) }
      render SummaryRow.new(label: "給与所得控除 (Deduction)", indent: true) { render MoneyDisplay.new(amount: -@it[:salary_deduction]) }
      render SummaryRow.new(label: "給与所得", highlight: true) { render MoneyDisplay.new(amount: @it[:salary_income]) }

      hr(class: "my-4")

      # Business income
      h3(class: "text-sm font-semibold text-gray-500 uppercase mb-2") { "事業所得 (Business Income)" }
      render SummaryRow.new(label: "事業収入 (Revenue)") { render MoneyDisplay.new(amount: @it[:business_revenue]) }
      render SummaryRow.new(label: "経費 (Expenses)", indent: true) { render MoneyDisplay.new(amount: -@it[:total_expenses]) }
      render SummaryRow.new(label: "青色申告特別控除", indent: true) { render MoneyDisplay.new(amount: -@it[:blue_deduction_applied]) }
      render SummaryRow.new(label: "事業所得", highlight: true) { render MoneyDisplay.new(amount: @it[:business_income]) }

      if @it[:loss_offset] != 0
        hr(class: "my-4")
        h3(class: "text-sm font-semibold text-gray-500 uppercase mb-2") { "損益通算 (Loss Offset)" }
        render SummaryRow.new(label: "事業の赤字を給与所得と相殺") { render MoneyDisplay.new(amount: @it[:loss_offset]) }
      end

      hr(class: "my-4")

      # Total income and deductions
      render SummaryRow.new(label: "合計所得金額", highlight: true) { render MoneyDisplay.new(amount: @it[:total_income]) }

      h3(class: "text-sm font-semibold text-gray-500 uppercase mt-4 mb-2") { "所得控除 (Deductions)" }
      render SummaryRow.new(label: "基礎控除", indent: true) { render MoneyDisplay.new(amount: @it[:basic_deduction]) }
      render SummaryRow.new(label: "社会保険料控除 (Salary)", indent: true) { render MoneyDisplay.new(amount: @it[:social_insurance_from_salary]) }
      if @it[:additional_deductions] > 0
        render SummaryRow.new(label: "その他控除", indent: true) { render MoneyDisplay.new(amount: @it[:additional_deductions]) }
      end
      render SummaryRow.new(label: "所得控除合計", highlight: true) { render MoneyDisplay.new(amount: @it[:total_deductions]) }

      hr(class: "my-4")

      # Tax calculation
      render SummaryRow.new(label: "課税所得 (Taxable Income)") { render MoneyDisplay.new(amount: @it[:taxable_income]) }
      render SummaryRow.new(label: "所得税額") { render MoneyDisplay.new(amount: @it[:income_tax_base]) }
      render SummaryRow.new(label: "復興特別所得税 (2.1%)", indent: true) { render MoneyDisplay.new(amount: @it[:reconstruction_tax]) }
      render SummaryRow.new(label: "税額合計") { render MoneyDisplay.new(amount: @it[:total_tax]) }
      render SummaryRow.new(label: "源泉徴収税額 (Already Paid)", indent: true) { render MoneyDisplay.new(amount: -@it[:tax_withheld]) }

      render SummaryRow.new(label: @it[:final_tax] >= 0 ? "納付額 (Amount to Pay)" : "還付額 (Refund)", highlight: true) do
        render MoneyDisplay.new(amount: @it[:final_tax], size: :lg)
      end
    end
  end

  def consumption_tax_section
    render Card.new(title: "消費税の比較 (Consumption Tax Comparison)") do
      render SummaryRow.new(label: "売上に含まれる消費税 (Output Tax)") { render MoneyDisplay.new(amount: @ct[:output_tax]) }
      render SummaryRow.new(label: "仕入税額控除 (Input Tax Credit)") { render MoneyDisplay.new(amount: @ct[:input_tax]) }

      hr(class: "my-4")

      # Three-column comparison
      div(class: "grid grid-cols-1 md:grid-cols-3 gap-4 mt-4") do
        @ct[:methods].each do |method_key, amount|
          recommended = method_key == @ct[:recommended]
          method_card(method_key, amount, recommended)
        end
      end

      if @ct[:non_eligible_tax] > 0
        p(class: "text-sm text-gray-500 mt-4") do
          plain "※ 非インボイス経費の消費税 "
          render MoneyDisplay.new(amount: @ct[:non_eligible_tax], size: :sm)
          plain " は本則課税では控除できません。"
        end
      end
    end
  end

  def method_card(method_key, amount, recommended)
    border = recommended ? "border-2 border-indigo-500" : "border border-gray-200"
    div(class: "rounded-lg p-4 text-center #{border}") do
      if recommended
        render Badge.new(text: "おすすめ", color: :indigo)
      end
      h4(class: "text-sm font-medium text-gray-700 mt-2") { METHOD_LABELS[method_key] }
      if amount < 0
        p(class: "text-xl font-bold text-green-600 mt-1") { "還付 #{format_money(-amount)}" }
      else
        p(class: "text-xl font-bold text-gray-900 mt-1") { format_money(amount) }
      end
    end
  end

  def format_money(amount)
    "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
  end
end
