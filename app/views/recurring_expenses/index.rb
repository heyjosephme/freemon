# frozen_string_literal: true

# The 定期経費 templates. Their due months show up on each year's dashboard.
class Views::RecurringExpenses::Index < Views::Base
  def initialize(recurring_expenses:)
    @recurring_expenses = recurring_expenses
  end

  def view_template
    render PageHeader.new(title: "定期経費 (Recurring Expenses)", back_path: root_path) do
      render Button.new(href: new_recurring_expense_path, size: :sm) { "＋ 定期経費を追加" }
    end

    if @recurring_expenses.empty?
      render EmptyState.new(
        message: "家賃・通信費・光熱費など毎回の支払いを登録しておくと、ダッシュボードに未登録の月が並びます。",
        action_text: "定期経費を追加",
        action_path: new_recurring_expense_path
      )
      return
    end

    render Card.new do
      div(class: "overflow-x-auto") do
        table(class: "min-w-full divide-y divide-gray-200") do
          thead do
            tr do
              th(class: th_classes) { "内容" }
              th(class: th_classes) { "カテゴリ" }
              th(class: "#{th_classes} text-right") { "金額" }
              th(class: "#{th_classes} text-right") { "按分率" }
              th(class: th_classes) { "支払日" }
              th(class: th_classes) { "期間" }
              th(class: th_classes) { "" }
            end
          end
          tbody(class: "divide-y divide-gray-100") do
            @recurring_expenses.each { |template| template_row(template) }
          end
        end
      end
      p(class: "mt-4 text-xs text-gray-500") do
        "支払日が今月までで未登録の月は、その年のダッシュボードの経費欄に出ます。登録すると通常の経費になり、あとで定期経費を変えても登録済みの経費は変わりません。"
      end
    end
  end

  private

  def template_row(template)
    tr do
      td(class: td_classes) do
        plain template.description
        span(class: "ml-2") { render Badge.new(text: "終了", color: :gray) } if template.ended?
      end
      td(class: td_classes) { render Badge.new(text: Expense::CATEGORY_LABELS[template.category], color: :gray) }
      td(class: "#{td_classes} text-right") { template.fixed_amount? ? yen(template.amount) : "毎回入力" }
      td(class: "#{td_classes} text-right") { "#{template.business_ratio}%" }
      td(class: td_classes) { template.schedule_label }
      td(class: td_classes) { template.period_label }
      td(class: "#{td_classes} text-right") do
        div(class: "flex gap-3 justify-end") do
          a(href: edit_recurring_expense_path(template), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
          button_to "削除", recurring_expense_path(template),
            method: :delete,
            class: "text-red-600 hover:text-red-800 text-sm",
            data: { turbo_confirm: "定期経費「#{template.description}」を削除しますか？登録済みの経費は残ります。" }
        end
      end
    end
  end

  def yen(amount) = "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"

  def th_classes
    "px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
  end

  def td_classes
    "px-4 py-3 text-sm text-gray-900 whitespace-nowrap"
  end
end
