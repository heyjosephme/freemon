# frozen_string_literal: true

class Views::FiscalYears::BalanceSheet < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 貸借対照表 (Balance Sheet)", back_path: fiscal_year_path(@fiscal_year))

    lines = JournalEntryLine
      .joins(:journal_entry, :account)
      .where(journal_entries: { fiscal_year_id: @fiscal_year.id })

    # Assets: debit-normal
    asset_accounts = Account.by_type(:asset)
    asset_totals = account_balances(lines, asset_accounts, credit_normal: false)
    total_assets = asset_totals.values.sum

    # Liabilities: credit-normal
    liability_accounts = Account.by_type(:liability)
    liability_totals = account_balances(lines, liability_accounts, credit_normal: true)
    total_liabilities = liability_totals.values.sum

    # Net income from P&L (revenue - expenses via journal entries)
    revenue_total = lines.joins(:account).where(accounts: { account_type: :revenue }, side: :credit).sum(:amount) -
                    lines.joins(:account).where(accounts: { account_type: :revenue }, side: :debit).sum(:amount)
    expense_total = lines.joins(:account).where(accounts: { account_type: :expense }, side: :debit).sum(:amount) -
                    lines.joins(:account).where(accounts: { account_type: :expense }, side: :credit).sum(:amount)
    net_income = revenue_total - expense_total

    total_liabilities_and_equity = total_liabilities + net_income

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      # Left: Assets
      render Card.new(title: "資産の部 (Assets)") do
        asset_totals.each do |account, amount|
          next if amount == 0
          render SummaryRow.new(label: account.display_name, indent: true) do
            render MoneyDisplay.new(amount: amount)
          end
        end

        render SummaryRow.new(label: "資産合計 (Total Assets)", highlight: true) do
          render MoneyDisplay.new(amount: total_assets, size: :lg)
        end
      end

      # Right: Liabilities + Equity
      render Card.new(title: "負債・資本の部 (Liabilities & Equity)") do
        h4(class: "text-xs font-semibold text-gray-500 uppercase mb-2") { "負債 (Liabilities)" }
        liability_totals.each do |account, amount|
          next if amount == 0
          render SummaryRow.new(label: account.display_name, indent: true) do
            render MoneyDisplay.new(amount: amount)
          end
        end
        render SummaryRow.new(label: "負債合計") do
          render MoneyDisplay.new(amount: total_liabilities)
        end

        hr(class: "my-3")

        h4(class: "text-xs font-semibold text-gray-500 uppercase mb-2") { "資本 (Equity)" }
        render SummaryRow.new(label: "当期純利益 (Net Income)", indent: true) do
          render MoneyDisplay.new(amount: net_income)
        end

        render SummaryRow.new(label: "負債・資本合計 (Total L&E)", highlight: true) do
          render MoneyDisplay.new(amount: total_liabilities_and_equity, size: :lg)
        end
      end
    end

    # Balance check
    balanced = total_assets == total_liabilities_and_equity
    div(class: "mt-6") do
      render Card.new do
        div(class: "text-center py-2") do
          if balanced
            p(class: "text-green-600 font-medium") { "資産 = 負債 + 資本 ✓ (Balance checks out)" }
          else
            p(class: "text-red-600 font-medium") do
              plain "資産 (#{format_yen(total_assets)}) ≠ 負債+資本 (#{format_yen(total_liabilities_and_equity)})"
            end
            p(class: "text-sm text-gray-500 mt-1") { "差額: #{format_yen(total_assets - total_liabilities_and_equity)}" }
          end
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
