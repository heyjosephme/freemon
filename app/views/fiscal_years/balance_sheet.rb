# frozen_string_literal: true

# Balances at the end of the year. Asset, liability and equity accounts carry
# over from earlier years (an asset bought last year is still on the books),
# except 事業主貸 and 事業主借, which are closed into 元入金 at every year end.
# 元入金 is what earlier years left the business with: their income, plus
# 事業主借, less 事業主貸.
class Views::FiscalYears::BalanceSheet < Views::Base
  OWNER_DRAWINGS = "190"     # 事業主貸
  OWNER_INVESTMENT = "290"   # 事業主借

  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 貸借対照表 (Balance Sheet)", back_path: fiscal_year_path(@fiscal_year))

    this_year = lines_for(FiscalYear.where(id: @fiscal_year.id))
    to_date = lines_for(FiscalYear.where(year: ..@fiscal_year.year))
    earlier = lines_for(FiscalYear.where(year: ...@fiscal_year.year))

    asset_totals = Account.by_type(:asset).to_h do |account|
      [ account, balance(account.code == OWNER_DRAWINGS ? this_year : to_date, account, credit_normal: false) ]
    end
    liability_totals = Account.by_type(:liability).to_h do |account|
      [ account, balance(account.code == OWNER_INVESTMENT ? this_year : to_date, account, credit_normal: true) ]
    end
    equity_totals = Account.by_type(:equity).to_h { |account| [ account, balance(to_date, account, credit_normal: true) ] }

    opening_capital = income(earlier) + code_balance(earlier, OWNER_INVESTMENT, credit_normal: true) -
                      code_balance(earlier, OWNER_DRAWINGS, credit_normal: false)
    net_income = income(this_year)

    total_assets = asset_totals.values.sum
    total_liabilities = liability_totals.values.sum
    total_liabilities_and_equity = total_liabilities + equity_totals.values.sum + opening_capital + net_income

    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      # Left: Assets
      render Card.new(title: "資産の部 (Assets)") do
        account_rows(asset_totals)
        render SummaryRow.new(label: "資産合計 (Total Assets)", highlight: true) do
          render MoneyDisplay.new(amount: total_assets, size: :lg)
        end
      end

      # Right: Liabilities + Equity
      render Card.new(title: "負債・資本の部 (Liabilities & Equity)") do
        h4(class: "text-xs font-semibold text-gray-500 uppercase mb-2") { "負債 (Liabilities)" }
        account_rows(liability_totals)
        render SummaryRow.new(label: "負債合計") do
          render MoneyDisplay.new(amount: total_liabilities)
        end

        hr(class: "my-3")

        h4(class: "text-xs font-semibold text-gray-500 uppercase mb-2") { "資本 (Equity)" }
        account_rows(equity_totals)
        render SummaryRow.new(label: "元入金（期首） (Opening Capital)", indent: true) do
          render MoneyDisplay.new(amount: opening_capital)
        end
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

  def lines_for(fiscal_years)
    JournalEntryLine.joins(:journal_entry).where(journal_entries: { fiscal_year_id: fiscal_years.select(:id) })
  end

  def account_rows(totals)
    totals.each do |account, amount|
      next if amount == 0
      render SummaryRow.new(label: account.display_name, indent: true) do
        render MoneyDisplay.new(amount: amount)
      end
    end
  end

  def balance(lines, account, credit_normal:)
    account_lines = lines.where(account_id: account.id)
    debit_total = account_lines.where(side: :debit).sum(:amount)
    credit_total = account_lines.where(side: :credit).sum(:amount)
    credit_normal ? (credit_total - debit_total) : (debit_total - credit_total)
  end

  def code_balance(lines, code, credit_normal:)
    account = Account.find_by(code: code)
    account ? balance(lines, account, credit_normal: credit_normal) : 0
  end

  # Revenue less expenses over the given lines.
  def income(lines)
    by_type = ->(type, side) { lines.joins(:account).where(accounts: { account_type: type }, side: side).sum(:amount) }
    (by_type.(:revenue, :credit) - by_type.(:revenue, :debit)) - (by_type.(:expense, :debit) - by_type.(:expense, :credit))
  end

  def format_yen(amount)
    if amount < 0
      "-¥#{ActiveSupport::NumberHelper.number_to_delimited(-amount)}"
    else
      "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
    end
  end
end
