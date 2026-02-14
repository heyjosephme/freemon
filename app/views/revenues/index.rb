# frozen_string_literal: true

class Views::Revenues::Index < Views::Base
  def initialize(fiscal_year:, revenues:)
    @fiscal_year = fiscal_year
    @revenues = revenues
  end

  def view_template
    render PageHeader.new(title: "事業収入 (Business Revenue)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: new_fiscal_year_revenue_path(@fiscal_year), size: :sm) { "＋ 売上を追加" }
    end

    if @revenues.any?
      render Card.new do
        table(class: "min-w-full divide-y divide-gray-200") do
          thead do
            tr do
              th(class: th_classes) { "日付" }
              th(class: th_classes) { "取引先" }
              th(class: "#{th_classes} text-right") { "金額 (税込)" }
              th(class: "#{th_classes} text-right") { "消費税" }
              th(class: th_classes) { "" }
            end
          end
          tbody(class: "divide-y divide-gray-100") do
            @revenues.each do |revenue|
              tr do
                td(class: td_classes) { revenue.date.to_s }
                td(class: td_classes) { revenue.client_name }
                td(class: "#{td_classes} text-right") { helpers.number_to_currency(revenue.amount, unit: "¥", precision: 0) }
                td(class: "#{td_classes} text-right text-gray-500") { helpers.number_to_currency(revenue.consumption_tax_component, unit: "¥", precision: 0) }
                td(class: "#{td_classes} text-right") do
                  div(class: "flex gap-3 justify-end") do
                    a(href: edit_fiscal_year_revenue_path(@fiscal_year, revenue), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
                    button_to "削除", fiscal_year_revenue_path(@fiscal_year, revenue),
                      method: :delete,
                      class: "text-red-600 hover:text-red-800 text-sm",
                      data: { turbo_confirm: "「#{revenue.client_name}」の売上 ¥#{ActiveSupport::NumberHelper.number_to_delimited(revenue.amount)} を削除しますか？" }
                  end
                end
              end
            end
          end
          tfoot do
            tr(class: "bg-gray-50") do
              td(class: "#{td_classes} font-medium", colspan: 2) { "合計" }
              td(class: "#{td_classes} text-right font-bold") { helpers.number_to_currency(@revenues.sum(:amount), unit: "¥", precision: 0) }
              td(class: "#{td_classes} text-right text-gray-500") { helpers.number_to_currency(@revenues.sum { |r| r.consumption_tax_component }, unit: "¥", precision: 0) }
              td { "" }
            end
          end
        end
      end
    else
      render EmptyState.new(
        message: "売上がまだ登録されていません。",
        action_text: "売上を追加",
        action_path: new_fiscal_year_revenue_path(@fiscal_year)
      )
    end
  end

  private

  def th_classes
    "px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
  end

  def td_classes
    "px-4 py-3 text-sm text-gray-900"
  end
end
