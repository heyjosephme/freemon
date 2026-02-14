# frozen_string_literal: true

class Views::FiscalYears::IncomeStatement < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 損益計算書 (Income Statement)", back_path: fiscal_year_path(@fiscal_year))

    lines = JournalEntryLine
      .joins(:journal_entry, :account)
      .where(journal_entries: { fiscal_year_id: @fiscal_year.id })

    # Revenue accounts: credit-normal, so sum credits - debits
    revenue_accounts = Account.by_type(:revenue)
    revenue_totals = account_balances(lines, revenue_accounts, credit_normal: true)
    total_revenue = revenue_totals.values.sum

    # Expense accounts: debit-normal, so sum debits - credits
    expense_accounts = Account.by_type(:expense)
    expense_totals = account_balances(lines, expense_accounts, credit_normal: false)
    total_expenses = expense_totals.values.sum

    net_income = total_revenue - total_expenses

    render Card.new do
      # Revenue section
      h3(class: "text-sm font-semibold text-gray-500 uppercase mb-3") { "収益の部 (Revenue)" }
      revenue_totals.each do |account, amount|
        next if amount == 0
        render SummaryRow.new(label: account.display_name, indent: true) do
          render MoneyDisplay.new(amount: amount)
        end
      end
      render SummaryRow.new(label: "収益合計 (Total Revenue)", highlight: true) do
        render MoneyDisplay.new(amount: total_revenue)
      end

      hr(class: "my-4")

      # Expense section
      h3(class: "text-sm font-semibold text-gray-500 uppercase mb-3") { "費用の部 (Expenses)" }
      expense_totals.each do |account, amount|
        next if amount == 0
        render SummaryRow.new(label: account.display_name, indent: true) do
          render MoneyDisplay.new(amount: amount)
        end
      end
      render SummaryRow.new(label: "費用合計 (Total Expenses)", highlight: true) do
        render MoneyDisplay.new(amount: total_expenses)
      end

      hr(class: "my-6")

      # Net income
      div(class: "text-center py-4") do
        h3(class: "text-lg font-semibold text-gray-700") { "当期純利益 (Net Income)" }
        p(class: "text-3xl font-bold mt-2 #{net_income >= 0 ? 'text-green-600' : 'text-red-600'}") do
          plain format_yen(net_income)
        end
      end
    end
  end

  private

  def account_balances(lines, accounts, credit_normal:)
    result = {}
    accounts.each do |account|
      account_lines = lines.where(account_id: account.id)
      debit_total = account_lines.where(side: :debit).sum(:amount)
      credit_total = account_lines.where(side: :credit).sum(:amount)
      balance = credit_normal ? (credit_total - debit_total) : (debit_total - credit_total)
      result[account] = balance
    end
    result
  end

  def format_yen(amount)
    if amount < 0
      "-¥#{ActiveSupport::NumberHelper.number_to_delimited(-amount)}"
    else
      "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
    end
  end
end
