# frozen_string_literal: true

# The app's navigation: a column down the left on wide screens, a bar across the
# top (links in one scrolling row) on narrow ones. Everything but 定期経費 and
# 勘定科目 belongs to a fiscal year, so the links point into the year being viewed,
# or the home year on pages that have none.
class Components::Sidebar < Components::Base
  ITEM = "flex items-center gap-2.5 whitespace-nowrap rounded-md px-3 py-1.5 text-sm"
  HEADING = "hidden lg:block px-3 pt-5 pb-1 text-xs font-medium text-subtle"

  def initialize(fiscal_years: [], active_fiscal_year: nil, current_path: nil)
    @fiscal_years = fiscal_years
    @active = active_fiscal_year if active_fiscal_year&.persisted?
    @year = @active || FiscalYear.home
    @current_path = current_path
  end

  def view_template
    nav(class: "bg-surface border-b border-line lg:sticky lg:top-0 lg:h-screen lg:w-56 lg:shrink-0 lg:overflow-y-auto lg:border-b-0 lg:border-r") do
      div(class: "flex items-center justify-between gap-4 px-4 pt-4 lg:block lg:px-5 lg:pt-6") do
        a(href: root_path, class: "font-display text-2xl font-semibold tracking-wide text-primary") { "Freemon" }
        div(class: "lg:mt-4") { year_switcher }
      end

      div(class: "flex gap-1 overflow-x-auto px-2 py-3 lg:block lg:px-2 lg:pb-6") do
        year_links if @year
        heading "共通 (Shared)"
        item "定期経費", "repeat", recurring_expenses_path
        item "勘定科目", "list-tree", accounts_path
      end
    end
  end

  private

  def year_links
    item "ホーム", "house", fiscal_year_path(@year), exact: true
    item "経費", "receipt-japanese-yen", fiscal_year_expenses_path(@year)
    item "売上", "banknote", fiscal_year_revenues_path(@year)

    heading "申告 (Filing)"
    item "給与所得", "briefcase", @year.salary_income ? fiscal_year_salary_income_path(@year) : new_fiscal_year_salary_income_path(@year)
    item "所得控除", "circle-minus", fiscal_year_deductions_path(@year)
    item "税額計算", "calculator", tax_summary_fiscal_year_path(@year)
    item "納税準備", "piggy-bank", tax_reserve_fiscal_year_path(@year)
    item "節税シミュレーション", "lightbulb", tax_saving_fiscal_year_path(@year)

    heading "レポート (Reports)"
    item "キャッシュフロー", "chart-column", cashflow_fiscal_year_path(@year)
    item "損益計算書", "trending-up", income_statement_fiscal_year_path(@year)
    item "貸借対照表", "scale", balance_sheet_fiscal_year_path(@year)

    heading "帳簿 (Books)"
    item "仕訳帳", "book-open", fiscal_year_journal_entries_path(@year)
    item "総勘定元帳", "book-text", general_ledger_fiscal_year_path(@year)
    item "減価償却", "trending-down", depreciation_fiscal_year_path(@year)
    item "償却資産税", "landmark", fixed_asset_tax_fiscal_year_path(@year)

    heading "#{@year.year}年"
    item "設定", "settings", edit_fiscal_year_path(@year)
  end

  def heading(text) = p(class: HEADING) { text }

  def item(text, icon, href, exact: false)
    current = @current_path == href || (!exact && @current_path.to_s.start_with?("#{href}/"))
    if current
      a(href: href, class: "#{ITEM} bg-primary-soft font-semibold text-primary", aria_current: "page") { icon_and_label(icon, text) }
    else
      a(href: href, class: "#{ITEM} text-muted hover:bg-sunken hover:text-ink") { icon_and_label(icon, text) }
    end
  end

  def icon_and_label(icon, text)
    render Components::Icon.new(icon, class: "h-4 w-4 shrink-0")
    plain text
  end

  def year_switcher
    details(class: "relative", data: { controller: "dropdown" }) do
      summary(class: "flex cursor-pointer list-none items-center justify-between gap-2 rounded-md bg-surface px-3 py-1.5 text-sm font-medium text-ink ring-1 ring-inset ring-line-strong hover:bg-sunken [&::-webkit-details-marker]:hidden") do
        plain(@year ? "#{@year.year}年" : "年度")
        span(class: "text-xs text-subtle", aria_hidden: "true") { "▾" }
      end
      div(class: "absolute right-0 z-10 mt-2 w-40 rounded-md bg-surface py-1 shadow-lg ring-1 ring-line lg:left-0 lg:right-auto") do
        @fiscal_years.each do |fiscal_year|
          a(href: fiscal_year_path(fiscal_year), class: menu_item_classes(active: fiscal_year == @year)) { "#{fiscal_year.year}年" }
        end
        div(class: "my-1 border-t border-line") if @fiscal_years.any?
        a(href: fiscal_years_path, class: menu_item_classes) { "すべての年度" }
      end
    end
  end

  def menu_item_classes(active: false)
    active ? "block px-4 py-2 text-sm font-semibold text-primary hover:bg-sunken" : "block px-4 py-2 text-sm text-ink hover:bg-sunken"
  end
end
