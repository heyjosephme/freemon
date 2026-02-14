# frozen_string_literal: true

class Views::SalaryIncomes::Show < Views::Base
  def initialize(fiscal_year:, salary_income:)
    @fiscal_year = fiscal_year
    @salary_income = salary_income
  end

  def view_template
    render PageHeader.new(title: "給与所得 (Salary Income)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: edit_fiscal_year_salary_income_path(@fiscal_year), variant: :secondary, size: :sm) { "編集" }
    end

    render Card.new do
      render SummaryRow.new(label: "支払金額 (Gross Salary)") do
        render MoneyDisplay.new(amount: @salary_income.gross_salary)
      end
      render SummaryRow.new(label: "給与所得控除 (Salary Deduction)") do
        render MoneyDisplay.new(amount: @salary_income.salary_deduction)
      end
      render SummaryRow.new(label: "給与所得 (Net Salary Income)", highlight: true) do
        render MoneyDisplay.new(amount: @salary_income.salary_income_amount)
      end

      hr(class: "my-4")

      render SummaryRow.new(label: "源泉徴収税額 (Tax Withheld)") do
        render MoneyDisplay.new(amount: @salary_income.tax_withheld)
      end
      render SummaryRow.new(label: "社会保険料 (Social Insurance)") do
        render MoneyDisplay.new(amount: @salary_income.social_insurance)
      end
    end
  end
end
