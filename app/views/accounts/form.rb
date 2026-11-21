# frozen_string_literal: true

class Views::Accounts::Form < Views::Base
  def initialize(account:)
    @account = account
  end

  def view_template
    form_with(model: @account, class: "max-w-2xl space-y-6") do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :code, "コード (Code)", class: LABEL
          f.text_field :code, class: input_classes, placeholder: "例: 511"
          errors_for(:code)
        end

        div(class: "mb-4") do
          f.label :name, "科目名 (Name)", class: LABEL
          f.text_field :name, class: input_classes, placeholder: "例: 減価償却費"
          errors_for(:name)
        end

        div(class: "mb-4") do
          f.label :name_en, "英語名 (English Name)", class: LABEL
          f.text_field :name_en, class: input_classes, placeholder: "例: Depreciation"
        end

        div(class: "mb-4") do
          f.label :account_type, "勘定種別 (Account Type)", class: LABEL
          f.select :account_type, Account::ACCOUNT_TYPE_LABELS.map { |k, v| [ v, k ] }, {}, class: input_classes
          errors_for(:account_type)
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@account.persisted? ? "更新" : "作成",
            class: Button.classes)
          a(href: accounts_path,
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end
  end

  private

  def errors_for(field)
    @account.errors[field].each do |error|
      p(class: "mt-1 text-sm text-negative") { error }
    end
  end

  def input_classes
    "block w-full #{INPUT}"
  end
end
