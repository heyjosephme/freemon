# frozen_string_literal: true

class Views::Expenses::Index < Views::Base
  def initialize(fiscal_year:, expenses:)
    @fiscal_year = fiscal_year
    @expenses = expenses
  end

  def view_template
    render PageHeader.new(title: "経費一覧 (Expenses)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: new_fiscal_year_expense_path(@fiscal_year), size: :sm) { "＋ 経費を追加" }
    end

    if @expenses.any?
      render Card.new do
        table(class: "min-w-full divide-y divide-gray-200") do
          thead do
            tr do
              th(class: th_classes) { "日付" }
              th(class: th_classes) { "内容" }
              th(class: th_classes) { "カテゴリ" }
              th(class: "#{th_classes} text-right") { "金額" }
              th(class: "#{th_classes} text-right") { "按分率" }
              th(class: "#{th_classes} text-right") { "控除額" }
              th(class: th_classes) { "" }
            end
          end
          tbody(class: "divide-y divide-gray-100") do
            @expenses.each do |expense|
              tr do
                td(class: td_classes) { expense.date.to_s }
                td(class: td_classes) do
                  plain expense.description
                  if expense.high_value?
                    span(class: "ml-2 text-xs text-yellow-600") { "(高額)" }
                  end
                  unless expense.invoice_eligible?
                    span(class: "ml-2 text-xs text-red-500") { "(非インボイス)" }
                  end
                end
                td(class: td_classes) do
                  render Badge.new(text: expense.category_label, color: :gray)
                end
                td(class: "#{td_classes} text-right") { helpers.number_to_currency(expense.amount, unit: "¥", precision: 0) }
                td(class: "#{td_classes} text-right") { "#{expense.business_ratio}%" }
                td(class: "#{td_classes} text-right") { helpers.number_to_currency(expense.deductible_amount, unit: "¥", precision: 0) }
                td(class: "#{td_classes} text-right") do
                  a(href: edit_fiscal_year_expense_path(@fiscal_year, expense), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
                end
              end
            end
          end
          tfoot do
            tr(class: "bg-gray-50") do
              td(class: "#{td_classes} font-medium", colspan: 3) { "合計" }
              td(class: "#{td_classes} text-right font-bold") { helpers.number_to_currency(@expenses.sum(:amount), unit: "¥", precision: 0) }
              td { "" }
              td(class: "#{td_classes} text-right font-bold") { helpers.number_to_currency(@fiscal_year.total_expenses, unit: "¥", precision: 0) }
              td { "" }
            end
          end
        end
      end
    else
      render EmptyState.new(
        message: "経費がまだ登録されていません。",
        action_text: "経費を追加",
        action_path: new_fiscal_year_expense_path(@fiscal_year)
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
