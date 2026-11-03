# frozen_string_literal: true

class Components::Navbar < Components::Base
  def initialize(fiscal_years: [], active_fiscal_year: nil)
    @fiscal_years = fiscal_years
    @active = active_fiscal_year if active_fiscal_year&.persisted?
  end

  def view_template
    nav(class: "bg-white border-b border-gray-200") do
      div(class: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8") do
        div(class: "flex justify-between h-16 items-center") do
          a(href: root_path, class: "text-xl font-bold text-indigo-600") { "Freemon" }
          div(class: "flex items-center gap-6") do
            year_switcher
            a(href: accounts_path, class: "text-sm text-gray-600 hover:text-gray-900") { "勘定科目" }
          end
        end
      end
    end
  end

  private

  def year_switcher
    details(class: "relative", data: { controller: "dropdown" }) do
      summary(class: "flex items-center gap-1 cursor-pointer list-none text-sm text-gray-600 hover:text-gray-900 [&::-webkit-details-marker]:hidden") do
        plain(@active ? "#{@active.year}年" : "年度")
        span(class: "text-xs text-gray-400", aria_hidden: "true") { "▾" }
      end
      div(class: "absolute right-0 z-10 mt-2 w-36 rounded-md bg-white py-1 shadow-lg ring-1 ring-black/5") do
        @fiscal_years.each do |fiscal_year|
          a(href: fiscal_year_path(fiscal_year), class: menu_item_classes(active: fiscal_year == @active)) { "#{fiscal_year.year}年" }
        end
        div(class: "my-1 border-t border-gray-100") if @fiscal_years.any?
        a(href: fiscal_years_path, class: menu_item_classes) { "すべての年度" }
      end
    end
  end

  def menu_item_classes(active: false)
    active ? "block px-4 py-2 text-sm font-semibold text-indigo-600 hover:bg-gray-50" : "block px-4 py-2 text-sm text-gray-700 hover:bg-gray-50"
  end
end
