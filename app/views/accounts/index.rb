# frozen_string_literal: true

class Views::Accounts::Index < Views::Base
  def initialize(accounts:)
    @accounts = accounts
  end

  def view_template
    render PageHeader.new(title: "勘定科目一覧 (Chart of Accounts)", back_path: root_path) do
      render Button.new(href: new_account_path, size: :sm) { "＋ 科目を追加" }
    end

    Account.account_types.keys.each do |type|
      accounts_of_type = @accounts.select { |a| a.account_type == type }
      next if accounts_of_type.empty?

      div(class: "mb-6") do
        render Card.new(title: Account::ACCOUNT_TYPE_LABELS[type]) do
          table(class: "min-w-full divide-y divide-gray-200") do
            thead do
              tr do
                th(class: th_classes) { "コード" }
                th(class: th_classes) { "科目名" }
                th(class: th_classes) { "英語名" }
                th(class: th_classes) { "" }
              end
            end
            tbody(class: "divide-y divide-gray-100") do
              accounts_of_type.each do |account|
                tr do
                  td(class: td_classes) { account.code }
                  td(class: "#{td_classes} font-medium") { account.name }
                  td(class: "#{td_classes} text-gray-500") { account.name_en || "" }
                  td(class: "#{td_classes} text-right") do
                    a(href: edit_account_path(account), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
                  end
                end
              end
            end
          end
        end
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
