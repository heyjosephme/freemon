# frozen_string_literal: true

class Views::Accounts::Form < Views::Base
  def initialize(account:)
    @account = account
  end

  def view_template
    form_with(model: @account, class: "space-y-6") do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :code, "コード (Code)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.text_field :code, class: input_classes, placeholder: "例: 511"
          errors_for(:code)
        end

        div(class: "mb-4") do
          f.label :name, "科目名 (Name)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.text_field :name, class: input_classes, placeholder: "例: 減価償却費"
          errors_for(:name)
        end

        div(class: "mb-4") do
          f.label :name_en, "英語名 (English Name)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.text_field :name_en, class: input_classes, placeholder: "例: Depreciation"
        end

        div(class: "mb-4") do
          f.label :account_type, "勘定種別 (Account Type)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.select :account_type, Account::ACCOUNT_TYPE_LABELS.map { |k, v| [ v, k ] }, {}, class: input_classes
          errors_for(:account_type)
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@account.persisted? ? "更新" : "作成",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: accounts_path,
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def errors_for(field)
    @account.errors[field].each do |error|
      p(class: "mt-1 text-sm text-red-600") { error }
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm"
  end
end
