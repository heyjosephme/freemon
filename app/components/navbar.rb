# frozen_string_literal: true

class Components::Navbar < Components::Base
  def view_template
    nav(class: "bg-white border-b border-gray-200") do
      div(class: "max-w-7xl mx-auto px-4 sm:px-6 lg:px-8") do
        div(class: "flex justify-between h-16 items-center") do
          a(href: root_path, class: "text-xl font-bold text-indigo-600") { "Freemon" }
          div(class: "flex gap-6") do
            a(href: fiscal_years_path, class: "text-sm text-gray-600 hover:text-gray-900") { "確定申告一覧" }
            a(href: accounts_path, class: "text-sm text-gray-600 hover:text-gray-900") { "勘定科目" }
          end
        end
      end
    end
  end
end
