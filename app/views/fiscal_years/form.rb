# frozen_string_literal: true

class Views::FiscalYears::Form < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    form_with(model: @fiscal_year, class: "space-y-6") do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :year, "年度 (Year)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.number_field :year, min: 2020, max: 2099, class: input_classes,
            placeholder: "例: 2025"
          errors_for(:year)
        end

        div(class: "mb-4") do
          f.label :filing_type, "申告種別 (Filing Type)", class: "block text-sm font-medium text-gray-700 mb-3"
          div(class: "space-y-2") do
            filing_type_radio(f, "blue_65", "青色申告 65万円控除", "e-Tax + 複式簿記")
            filing_type_radio(f, "blue_10", "青色申告 10万円控除", "簡易簿記")
            filing_type_radio(f, "white", "白色申告", "特別控除なし")
          end
          errors_for(:filing_type)
        end

        div(class: "flex gap-3") do
          f.submit(@fiscal_year.persisted? ? "更新" : "作成",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: @fiscal_year.persisted? ? fiscal_year_path(@fiscal_year) : fiscal_years_path,
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def filing_type_radio(f, value, label, description)
    div(class: "flex items-start") do
      f.radio_button :filing_type, value,
        class: "mt-1 h-4 w-4 border-gray-300 text-indigo-600 focus:ring-indigo-600"
      label(class: "ml-3") do
        span(class: "block text-sm font-medium text-gray-900") { label }
        span(class: "block text-sm text-gray-500") { description }
      end
    end
  end

  def errors_for(field)
    @fiscal_year.errors[field].each do |error|
      p(class: "mt-1 text-sm text-red-600") { error }
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
