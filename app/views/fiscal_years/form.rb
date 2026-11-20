# frozen_string_literal: true

class Views::FiscalYears::Form < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    form_with(model: @fiscal_year, class: "space-y-6") do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :year, "年度 (Year)", class: LABEL
          f.number_field :year, min: 2020, max: 2099, class: input_classes,
            placeholder: "例: 2025"
          errors_for(:year)
        end

        div(class: "mb-4") do
          f.label :filing_type, "申告種別 (Filing Type)", class: "block text-sm font-medium text-ink mb-3"
          div(class: "space-y-2") do
            filing_type_radio(f, "blue_65", "青色申告 65万円控除", "e-Tax + 複式簿記")
            filing_type_radio(f, "blue_10", "青色申告 10万円控除", "簡易簿記")
            filing_type_radio(f, "white", "白色申告", "特別控除なし")
          end
          errors_for(:filing_type)
        end

        div(class: "flex gap-3") do
          f.submit(@fiscal_year.persisted? ? "更新" : "作成",
            class: Button.classes)
          a(href: @fiscal_year.persisted? ? fiscal_year_path(@fiscal_year) : fiscal_years_path,
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end
  end

  private

  def filing_type_radio(f, value, label, description)
    div(class: "flex items-start") do
      f.radio_button :filing_type, value,
        class: "mt-1 h-4 w-4 accent-primary"
      label(class: "ml-3") do
        span(class: "block text-sm font-medium text-ink") { label }
        span(class: "block text-sm text-muted") { description }
      end
    end
  end

  def errors_for(field)
    @fiscal_year.errors[field].each do |error|
      p(class: "mt-1 text-sm text-negative") { error }
    end
  end

  def input_classes
    "block w-full #{INPUT}"
  end
end
