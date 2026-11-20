# frozen_string_literal: true

class Views::FiscalYears::Cashflow < Views::Base
  def initialize(fiscal_year:, report:)
    @fiscal_year = fiscal_year
    @report = report
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 キャッシュフロー (Cashflow)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: tax_reserve_fiscal_year_path(@fiscal_year), size: :sm) { "納税準備" }
    end

    totals = @report.totals
    if totals[:revenue].zero? && totals[:expense].zero?
      render EmptyState.new(
        message: "この年度には収入・経費の記録がまだありません。",
        action_text: "ダッシュボードへ戻る",
        action_path: fiscal_year_path(@fiscal_year)
      )
      return
    end

    summary_cards(totals)
    monthly_chart_card
    breakdown_cards
  end

  private

  def summary_cards(totals)
    div(class: "grid grid-cols-1 md:grid-cols-3 gap-4 mb-6") do
      tile("収入 (Cash In)", totals[:revenue], "text-primary")
      tile("支出 (Cash Out)", totals[:expense], "text-negative")
      tile("差引残高 (Net)", totals[:net], totals[:net] >= 0 ? "text-positive" : "text-negative")
    end
  end

  def tile(label, amount, color)
    render Card.new do
      p(class: "text-sm text-muted mb-1") { label }
      p(class: "font-display font-semibold tabular-nums text-2xl #{color}") { yen(amount) }
    end
  end

  def monthly_chart_card
    div(class: "mb-6") do
      render Card.new(title: "月次キャッシュフロー (Monthly Cashflow)") do
        legend
        render Components::Charts::MonthlyCashflow.new(months: @report.months)
        p(class: "text-xs text-subtle mt-3") { "※ 実際の入出金額です（経費は家事按分前の全額）。折れ線は累計残高を示します。" }
      end
    end
  end

  def legend
    div(class: "flex flex-wrap gap-4 mb-4 text-xs text-muted") do
      legend_item("bg-primary", "収入 (Revenue)")
      legend_item("bg-negative", "支出 (Expense)")
      legend_item("bg-ink", "累計残高 (Cumulative)")
    end
  end

  def legend_item(color, label)
    div(class: "flex items-center gap-1.5") do
      span(class: "inline-block w-3 h-3 rounded-sm #{color}")
      plain label
    end
  end

  def breakdown_cards
    div(class: "grid grid-cols-1 md:grid-cols-2 gap-6") do
      render Card.new(title: "取引先別 収入 (Revenue by Client)") do
        render Components::Charts::ProportionBars.new(slices: @report.by_client, color: "bg-primary")
      end
      render Card.new(title: "カテゴリ別 経費 (Expenses by Category)") do
        render Components::Charts::ProportionBars.new(slices: @report.by_category, color: "bg-negative")
      end
    end
  end

  def yen(amount)
    sign = amount.negative? ? "-" : ""
    "#{sign}¥#{ActiveSupport::NumberHelper.number_to_delimited(amount.abs)}"
  end
end
