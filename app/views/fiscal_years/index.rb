# frozen_string_literal: true

class Views::FiscalYears::Index < Views::Base
  def initialize(fiscal_years:)
    @fiscal_years = fiscal_years
  end

  def view_template
    render PageHeader.new(title: "確定申告一覧 (Tax Filings)") do
      render Button.new(href: new_fiscal_year_path) { "＋ 新規作成" }
    end

    if @fiscal_years.any?
      div(class: "grid gap-4") do
        @fiscal_years.each do |fy|
          render fiscal_year_card(fy)
        end
      end
    else
      render EmptyState.new(
        message: "確定申告年度がまだありません。",
        action_text: "最初の年度を作成",
        action_path: new_fiscal_year_path
      )
    end
  end

  private

  def fiscal_year_card(fy)
    proc {
      a(href: fiscal_year_path(fy), class: "block") do
        render Card.new do
          div(class: "flex items-center justify-between") do
            div do
              h3(class: "text-lg font-semibold text-gray-900") { "#{fy.year}年 確定申告" }
              render Badge.new(text: fy.filing_type_label, color: fy.white? ? :gray : :indigo)
            end
            div(class: "text-right text-sm text-gray-500") do
              p { "売上: #{helpers.number_to_currency(fy.total_revenue, unit: '¥', precision: 0)}" }
              p { "経費: #{helpers.number_to_currency(fy.total_expenses, unit: '¥', precision: 0)}" }
            end
          end
        end
      end
    }
  end
end
