# frozen_string_literal: true

class Views::FiscalYears::GeneralLedger < Views::Base
  def initialize(fiscal_year:, account:, journal_entries:, accounts:)
    @fiscal_year = fiscal_year
    @account = account
    @journal_entries = journal_entries
    @accounts = accounts
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 総勘定元帳 (General Ledger)", back_path: fiscal_year_path(@fiscal_year))

    # Account selector
    render Card.new do
      form(action: general_ledger_fiscal_year_path(@fiscal_year), method: "get", class: "flex gap-3 items-end", data: { controller: "auto-submit" }) do
        div(class: "flex-1") do
          label(for: "account_id", class: "block text-sm font-medium text-gray-700 mb-1") { "勘定科目" }
          select(name: "account_id", id: "account_id", class: input_classes, data: { action: "change->auto-submit#submit" }) do
            @accounts.each do |acc|
              if acc.id == @account&.id
                option(value: acc.id, selected: true) { acc.display_name_with_en }
              else
                option(value: acc.id) { acc.display_name_with_en }
              end
            end
          end
        end
      end
    end

    return unless @account

    div(class: "mt-6") do
      render Card.new(title: "#{@account.display_name} (#{@account.account_type_label})") do
        if @journal_entries.any?
          running_balance = 0

          table(class: "min-w-full divide-y divide-gray-200") do
            thead do
              tr do
                th(class: th_classes) { "日付" }
                th(class: th_classes) { "摘要" }
                th(class: "#{th_classes} text-right") { "借方" }
                th(class: "#{th_classes} text-right") { "貸方" }
                th(class: "#{th_classes} text-right") { "残高" }
              end
            end
            tbody(class: "divide-y divide-gray-100") do
              @journal_entries.each do |je|
                lines_for_account = je.lines.select { |l| l.account_id == @account.id }

                lines_for_account.each do |line|
                  debit_amount = line.debit? ? line.amount : 0
                  credit_amount = line.credit? ? line.amount : 0

                  # For debit-normal accounts (assets, expenses): debits increase, credits decrease
                  # For credit-normal accounts (liabilities, equity, revenue): credits increase, debits decrease
                  if @account.debit_normal?
                    running_balance += debit_amount - credit_amount
                  else
                    running_balance += credit_amount - debit_amount
                  end

                  tr do
                    td(class: td_classes) { je.date.to_s }
                    td(class: td_classes) { je.description }
                    td(class: "#{td_classes} text-right") { debit_amount > 0 ? format_yen(debit_amount) : "" }
                    td(class: "#{td_classes} text-right") { credit_amount > 0 ? format_yen(credit_amount) : "" }
                    td(class: "#{td_classes} text-right font-medium") { format_yen(running_balance) }
                  end
                end
              end
            end
            tfoot do
              tr(class: "bg-gray-50") do
                td(class: "#{td_classes} font-bold", colspan: 4) { "期末残高" }
                td(class: "#{td_classes} text-right font-bold") { format_yen(running_balance) }
              end
            end
          end
        else
          p(class: "text-gray-500 text-center py-8") { "この勘定科目の取引はありません。" }
        end
      end
    end
  end

  private

  def format_yen(amount)
    if amount < 0
      "-¥#{ActiveSupport::NumberHelper.number_to_delimited(-amount)}"
    else
      "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm"
  end

  def th_classes
    "px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
  end

  def td_classes
    "px-4 py-3 text-sm text-gray-900"
  end
end
