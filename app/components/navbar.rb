# frozen_string_literal: true

class Components::Navbar < Components::Base
  NAV_LINK = "text-sm text-muted hover:text-ink"

  def initialize(fiscal_years: [], active_fiscal_year: nil)
    @fiscal_years = fiscal_years
    @active = active_fiscal_year if active_fiscal_year&.persisted?
  end

  def view_template
    nav(class: "bg-surface border-b border-line") do
      div(class: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8") do
        div(class: "flex justify-between h-14 items-center") do
          a(href: root_path, class: "font-display text-xl font-semibold tracking-wide text-primary") { "Freemon" }
          div(class: "flex items-center gap-6") do
            year_switcher
            a(href: recurring_expenses_path, class: NAV_LINK) { "定期経費" }
            a(href: accounts_path, class: NAV_LINK) { "勘定科目" }
          end
        end
      end
    end
  end

  private

  def year_switcher
    details(class: "relative", data: { controller: "dropdown" }) do
      summary(class: "flex items-center gap-1 cursor-pointer list-none #{NAV_LINK} [&::-webkit-details-marker]:hidden") do
        plain(@active ? "#{@active.year}年" : "年度")
        span(class: "text-xs text-subtle", aria_hidden: "true") { "▾" }
      end
      div(class: "absolute right-0 z-10 mt-2 w-36 rounded-md bg-surface py-1 shadow-lg ring-1 ring-line") do
        @fiscal_years.each do |fiscal_year|
          a(href: fiscal_year_path(fiscal_year), class: menu_item_classes(active: fiscal_year == @active)) { "#{fiscal_year.year}年" }
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
