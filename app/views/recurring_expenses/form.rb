# frozen_string_literal: true

class Views::RecurringExpenses::Form < Views::Base
  def initialize(recurring_expense:)
    @recurring_expense = recurring_expense
  end

  def view_template
    form_with(model: @recurring_expense, class: "space-y-6") do |f|
      render Card.new do
        field(f, :description, "内容 (Description)", type: :text_field, placeholder: "例: 家賃、インターネット、電気代")
        field(f, :amount, "金額 税込 (Amount, tax included)", type: :number_field, min: 1, placeholder: "¥",
          hint: "毎回同じ金額なら入力します。電気代・携帯代など毎回変わるなら空欄にして、登録のときに入力します。")
        select_field(f, :category, "カテゴリ (Category)", Expense::CATEGORY_LABELS.map { |key, label| [ label, key ] })
        field(f, :business_ratio, "家事按分率 (Business Use %)", type: :number_field, min: 1, max: 100,
          hint: "事業で使用している割合 (1-100%)。毎回この割合で登録されます。")
        # A select rather than a checkbox so the status can stay unset: "" saves nil.
        select_field(f, :invoice_eligible, "インボイス (Invoice)", [ [ "未設定（管理しない）", "" ], [ "あり（適格請求書あり）", true ], [ "なし", false ] ],
          hint: "住宅の家賃は消費税が非課税なので「なし」か「未設定」にします。本則課税では「あり」の経費だけが仕入税額控除の対象です。")
        select_field(f, :purchase_channel, "購入方法 (Purchased)", Expense::PURCHASE_CHANNEL_LABELS.map { |key, label| [ label, key ] },
          hint: "口座振替・振込・カード払いや電子明細の請求は「オンライン」に。要領収書の対象になりません。")
        select_field(f, :interval_months, "間隔 (Repeats)", RecurringExpense::INTERVALS.map { |months, label| [ label, months ] },
          hint: "水道は2か月ごとの請求が多いです。")
        field(f, :starts_on, "初回の支払日 (First payment)", type: :date_field,
          hint: "この日の分からダッシュボードに出て、以後も同じ日（短い月は月末）の日付で登録します。手入力済みの月より後の日付にしてください。")
        field(f, :ends_on, "終了日 (Ends)", type: :date_field, hint: "解約や引っ越しで終わったら入力します。空欄なら続きます。")
        skipped_months if @recurring_expense.skipped_months.any?

        div(class: "flex gap-3 pt-4") do
          f.submit(@recurring_expense.persisted? ? "更新" : "追加",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: recurring_expenses_path,
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  # Kept while checked, like AttachedFiles: unchecking a month puts it back on the dashboard.
  # The blank value submits the list even with every box unchecked.
  def skipped_months
    fieldset(class: "mb-4") do
      legend(class: "block text-sm font-medium text-gray-700 mb-1") { "スキップした月 (Skipped)" }
      input(type: "hidden", name: "recurring_expense[skipped_months][]", value: "")
      div(class: "flex flex-wrap gap-x-4 gap-y-1") do
        @recurring_expense.skipped_months.each do |month|
          date = Date.iso8601(month)
          label(class: "inline-flex items-center gap-1.5 text-sm text-gray-700") do
            input(type: "checkbox", name: "recurring_expense[skipped_months][]", value: month, checked: true,
                  class: "rounded border-gray-300 text-indigo-600")
            plain "#{date.year}年#{date.month}月"
          end
        end
      end
      p(class: "mt-1 text-sm text-gray-500") { "チェックを外して更新すると、その月がまたダッシュボードに出ます。" }
    end
  end

  def field(f, attr, label, type:, hint: nil, **opts)
    div(class: "mb-4") do
      f.label attr, label, class: "block text-sm font-medium text-gray-700 mb-1"
      f.send(type, attr, class: input_classes, **opts)
      field_notes(attr, hint)
    end
  end

  def select_field(f, attr, label, choices, hint: nil)
    div(class: "mb-4") do
      f.label attr, label, class: "block text-sm font-medium text-gray-700 mb-1"
      f.select attr, choices, {}, class: input_classes
      field_notes(attr, hint)
    end
  end

  def field_notes(attr, hint)
    p(class: "mt-1 text-sm text-gray-500") { hint } if hint
    @recurring_expense.errors[attr].each do |error|
      p(class: "mt-1 text-sm text-red-600") { error }
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
