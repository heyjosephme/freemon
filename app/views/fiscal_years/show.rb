# frozen_string_literal: true

class Views::FiscalYears::Show < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 確定申告", back_path: fiscal_years_path) do
      render Button.new(href: edit_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "設定" }
      render Button.new(href: tax_summary_fiscal_year_path(@fiscal_year), size: :sm) { "税額計算" }
    end

    div(class: "mb-4") do
      render Badge.new(text: @fiscal_year.filing_type_label, color: @fiscal_year.white? ? :gray : :indigo)
    end

    # Bookkeeping section
    div(class: "mb-6") do
      render Card.new(title: "帳簿・レポート (Bookkeeping & Reports)") do
        div(class: "grid grid-cols-2 md:grid-cols-5 gap-3") do
          render Button.new(href: fiscal_year_journal_entries_path(@fiscal_year), variant: :secondary, size: :sm) { "仕訳帳" }
          render Button.new(href: general_ledger_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "総勘定元帳" }
          render Button.new(href: income_statement_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "損益計算書" }
          render Button.new(href: balance_sheet_fiscal_year_path(@fiscal_year), variant: :secondary, size: :sm) { "貸借対照表" }
          render Button.new(href: tax_summary_fiscal_year_path(@fiscal_year), size: :sm) { "税額計算" }
        end
      end
    end

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      salary_card
      revenue_card
      expense_card
      deduction_card
    end
  end

  private

  def salary_card
    si = @fiscal_year.salary_income

    render Card.new(title: "給与所得 (Salary Income)") do
      if si
        render SummaryRow.new(label: "支払金額 (Gross Salary)") do
          render MoneyDisplay.new(amount: si.gross_salary)
        end
        render SummaryRow.new(label: "給与所得控除 (Salary Deduction)") do
          render MoneyDisplay.new(amount: si.salary_deduction)
        end
        render SummaryRow.new(label: "給与所得 (Net Salary Income)", highlight: true) do
          render MoneyDisplay.new(amount: si.salary_income_amount)
        end
        div(class: "mt-4") do
          render Button.new(href: fiscal_year_salary_income_path(@fiscal_year), variant: :secondary, size: :sm) { "詳細" }
        end
      else
        render EmptyState.new(
          message: "給与情報が未入力です。",
          action_text: "給与情報を入力",
          action_path: new_fiscal_year_salary_income_path(@fiscal_year)
        )
      end
    end
  end

  def revenue_card
    revenues = @fiscal_year.revenues
    total = revenues.sum(:amount)

    render Card.new(title: "事業収入 (Business Revenue)") do
      if revenues.any?
        render SummaryRow.new(label: "件数 (Entries)", value: "#{revenues.count}件")
        render SummaryRow.new(label: "合計 (Total)", highlight: true) do
          render MoneyDisplay.new(amount: total)
        end
        div(class: "mt-4") do
          render Button.new(href: fiscal_year_revenues_path(@fiscal_year), variant: :secondary, size: :sm) { "一覧" }
        end
      else
        render EmptyState.new(
          message: "売上がまだ登録されていません。",
          action_text: "売上を追加",
          action_path: new_fiscal_year_revenue_path(@fiscal_year)
        )
      end
    end
  end

  def expense_card
    expenses = @fiscal_year.expenses
    total = @fiscal_year.total_expenses

    render Card.new(title: "経費 (Expenses)") do
      if expenses.any?
        render SummaryRow.new(label: "件数 (Entries)", value: "#{expenses.count}件")
        render SummaryRow.new(label: "控除後合計 (Total after 家事按分)", highlight: true) do
          render MoneyDisplay.new(amount: total)
        end
        div(class: "mt-4") do
          render Button.new(href: fiscal_year_expenses_path(@fiscal_year), variant: :secondary, size: :sm) { "一覧" }
        end
      else
        render EmptyState.new(
          message: "経費がまだ登録されていません。",
          action_text: "経費を追加",
          action_path: new_fiscal_year_expense_path(@fiscal_year)
        )
      end
    end
  end

  def deduction_card
    deductions = @fiscal_year.deductions
    total = deductions.sum(:amount)

    render Card.new(title: "所得控除 (Deductions)") do
      si_insurance = @fiscal_year.salary_income&.social_insurance || 0
      render SummaryRow.new(label: "基礎控除 (Basic)") do
        render MoneyDisplay.new(amount: 480_000)
      end
      if si_insurance > 0
        render SummaryRow.new(label: "社会保険料 (From salary)") do
          render MoneyDisplay.new(amount: si_insurance)
        end
      end

      if deductions.any?
        render SummaryRow.new(label: "追加控除 (Additional)", value: "#{deductions.count}件") do
          render MoneyDisplay.new(amount: total)
        end
        div(class: "mt-4") do
          render Button.new(href: fiscal_year_deductions_path(@fiscal_year), variant: :secondary, size: :sm) { "一覧" }
        end
      else
        render EmptyState.new(
          message: "追加の所得控除がありません。",
          action_text: "控除を追加",
          action_path: new_fiscal_year_deduction_path(@fiscal_year)
        )
      end
    end
  end
end
