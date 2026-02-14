# frozen_string_literal: true

class Views::Expenses::Form < Views::Base
  def initialize(fiscal_year:, expense:)
    @fiscal_year = fiscal_year
    @expense = expense
  end

  def view_template
    url = @expense.persisted? ? fiscal_year_expense_path(@fiscal_year, @expense) : fiscal_year_expenses_path(@fiscal_year)

    form_with(model: @expense, url: url, class: "space-y-6") do |f|
      render Card.new do
        field(f, :description, "内容 (Description)", type: :text_field, placeholder: "例: コワーキングスペース利用料")
        field(f, :amount, "金額 税込 (Amount, tax included)", type: :number_field, min: 1, placeholder: "¥")
        field(f, :date, "日付 (Date)", type: :date_field)

        div(class: "mb-4") do
          f.label :category, "カテゴリ (Category)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.select :category, Expense::CATEGORY_LABELS.map { |k, v| [ v, k ] }, {}, class: input_classes
          @expense.errors[:category].each do |error|
            p(class: "mt-1 text-sm text-red-600") { error }
          end
        end

        field(f, :business_ratio, "家事按分率 (Business Use %)", type: :number_field, min: 1, max: 100,
          hint: "事業で使用している割合 (1-100%)")

        div(class: "mb-4") do
          div(class: "flex items-center") do
            f.check_box :invoice_eligible, class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600"
            f.label :invoice_eligible, "インボイス対応 (Invoice Eligible)", class: "ml-2 text-sm text-gray-700"
          end
          p(class: "mt-1 text-sm text-gray-500") { "取引先がインボイス登録事業者の場合はチェック" }
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@expense.persisted? ? "更新" : "登録",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: fiscal_year_expenses_path(@fiscal_year),
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def field(f, attr, label, type:, hint: nil, **opts)
    div(class: "mb-4") do
      f.label attr, label, class: "block text-sm font-medium text-gray-700 mb-1"
      f.send(type, attr, class: input_classes, **opts)
      if hint
        p(class: "mt-1 text-sm text-gray-500") { hint }
      end
      @expense.errors[attr].each do |error|
        p(class: "mt-1 text-sm text-red-600") { error }
      end
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
