# frozen_string_literal: true

class Views::Expenses::Form < Views::Base
  def initialize(fiscal_year:, expense:, back_path:, return_to: nil)
    @fiscal_year = fiscal_year
    @expense = expense
    @back_path = back_path
    @return_to = return_to
  end

  def view_template
    url = @expense.persisted? ? fiscal_year_expense_path(@fiscal_year, @expense) : fiscal_year_expenses_path(@fiscal_year)

    form_with(model: @expense, url: url, class: "space-y-6") do |f|
      input(type: "hidden", name: "return_to", value: @return_to) if @return_to
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

        asset_fields(f)

        field(f, :business_ratio, "家事按分率 (Business Use %)", type: :number_field, min: 1, max: 100,
          hint: "事業で使用している割合 (1-100%)")

        div(class: "mb-4") do
          f.label :invoice_eligible, "インボイス (Invoice)", class: "block text-sm font-medium text-gray-700 mb-1"
          # A select rather than a checkbox so the status can stay unset: "" saves nil.
          f.select :invoice_eligible, [ [ "未設定（管理しない）", "" ], [ "あり（適格請求書あり）", true ], [ "なし", false ] ], {}, class: input_classes
          p(class: "mt-1 text-sm text-gray-500") { "本則課税では「あり」の経費だけが仕入税額控除の対象です。簡易課税・2割特例なら未設定で構いません。" }
        end

        div(class: "mb-4") do
          f.label :purchase_channel, "購入方法 (Purchased)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.select :purchase_channel, Expense::PURCHASE_CHANNEL_LABELS.map { |key, label| [ label, key ] }, {}, class: input_classes
          p(class: "mt-1 text-sm text-gray-500") { "オンラインは電子領収書がメールで届くので撮影は不要です。店頭・対面は紙の領収書を撮影して添付しましょう。" }
        end

        div(class: "mb-4") do
          f.label :receipts, "領収書・請求書 (Receipts/Invoices)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.file_field :receipts, multiple: true, accept: ".pdf,.png,.jpg,.jpeg",
            class: "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
          p(class: "mt-1 text-sm text-gray-500") { "PDF, PNG, JPG (複数選択可)" }
        end

        render AttachedFiles.new(attachments: @expense.receipts, field_name: "expense[receipts][]")

        div(class: "flex gap-3 pt-4") do
          f.submit(@expense.persisted? ? "更新" : "登録",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: @back_path,
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  # 区分, plus the 設備・資産 fields, which only show while 区分 is 設備・資産.
  def asset_fields(f)
    div(class: "mb-4", data: { controller: "asset-fields" }) do
      f.label :kind, "区分 (Type)", class: "block text-sm font-medium text-gray-700 mb-1"
      f.select :kind, Expense::KIND_LABELS.map { |key, label| [ label, key ] }, {},
        class: input_classes, data: { asset_fields_target: "kind", action: "asset-fields#toggle" }
      p(class: "mt-1 text-sm text-gray-500") { "10万円以上のパソコン・カメラ・家具などは「設備・資産」にすると、償却方法に沿って計上されます。" }

      fieldset(class: "mt-3 rounded-md border border-gray-200 p-4", data: { asset_fields_target: "fields" }) do
        legend(class: "px-1 text-sm font-medium text-gray-700") { "設備・資産の場合" }
        div(class: "mb-4") do
          f.label :accounting_method, "償却方法 (Accounting method)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.select :accounting_method, [ [ "自動（金額から判定）", "" ], *Expense::ACCOUNTING_METHOD_LABELS.map { |key, label| [ label, key ] } ], {},
            class: input_classes
          p(class: "mt-1 text-sm text-gray-500") { "自動: 10万円未満は全額経費、40万円未満は少額減価償却資産の特例（青色申告）、それ以上は定額法。" }
          @expense.errors[:accounting_method].each do |error|
            p(class: "mt-1 text-sm text-red-600") { error }
          end
        end
        field(f, :useful_life, "耐用年数 (Useful life, years)", type: :number_field, min: 2, max: 50,
          hint: "定額法のときだけ。例: パソコン 4年、サーバー・カメラ・ソフトウェア 5年、普通自動車 6年")
      end
    end
  end

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
