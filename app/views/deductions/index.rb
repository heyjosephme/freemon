# frozen_string_literal: true

class Views::Deductions::Index < Views::Base
  def initialize(fiscal_year:, deductions:)
    @fiscal_year = fiscal_year
    @deductions = deductions
  end

  def view_template
    render PageHeader.new(title: "所得控除 (Deductions)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: new_fiscal_year_deduction_path(@fiscal_year), size: :sm) { "＋ 控除を追加" }
    end

    render Card.new(title: "自動適用される控除") do
      render SummaryRow.new(label: "基礎控除 (Basic Deduction)") do
        render MoneyDisplay.new(amount: 480_000)
      end
      si = @fiscal_year.salary_income
      if si
        render SummaryRow.new(label: "社会保険料控除 (Social Insurance from salary)") do
          render MoneyDisplay.new(amount: si.social_insurance)
        end
      end
    end

    if @deductions.any?
      div(class: "mt-6") do
        render Card.new(title: "追加の控除") do
          table(class: "min-w-full divide-y divide-gray-200") do
            thead do
              tr do
                th(class: th_classes) { "種別" }
                th(class: "#{th_classes} text-right") { "金額" }
                th(class: th_classes) { "" }
              end
            end
            tbody(class: "divide-y divide-gray-100") do
              @deductions.each do |deduction|
                tr do
                  td(class: td_classes) { deduction.deduction_type_label }
                  td(class: "#{td_classes} text-right") { helpers.number_to_currency(deduction.amount, unit: "¥", precision: 0) }
                  td(class: "#{td_classes} text-right") do
                    div(class: "flex gap-3 justify-end") do
                      a(href: edit_fiscal_year_deduction_path(@fiscal_year, deduction), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
                      button_to "削除", fiscal_year_deduction_path(@fiscal_year, deduction),
                        method: :delete,
                        class: "text-red-600 hover:text-red-800 text-sm",
                        data: { turbo_confirm: "「#{deduction.deduction_type_label}」¥#{ActiveSupport::NumberHelper.number_to_delimited(deduction.amount)} を削除しますか？" }
                    end
                  end
                end
              end
            end
            tfoot do
              tr(class: "bg-gray-50") do
                td(class: "#{td_classes} font-medium") { "追加控除合計" }
                td(class: "#{td_classes} text-right font-bold") { helpers.number_to_currency(@deductions.sum(:amount), unit: "¥", precision: 0) }
                td { "" }
              end
            end
          end
        end
      end
    else
      div(class: "mt-6") do
        render EmptyState.new(
          message: "追加の所得控除はまだ登録されていません。",
          action_text: "控除を追加",
          action_path: new_fiscal_year_deduction_path(@fiscal_year)
        )
      end
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
