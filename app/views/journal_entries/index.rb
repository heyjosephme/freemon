# frozen_string_literal: true

class Views::JournalEntries::Index < Views::Base
  def initialize(fiscal_year:, journal_entries:)
    @fiscal_year = fiscal_year
    @journal_entries = journal_entries
  end

  def view_template
    render PageHeader.new(title: "仕訳帳 (Journal)", back_path: fiscal_year_path(@fiscal_year)) do
      render Button.new(href: new_fiscal_year_journal_entry_path(@fiscal_year), size: :sm) { "＋ 手動仕訳" }
    end

    if @journal_entries.any?
      render Card.new do
        table(class: "min-w-full divide-y divide-gray-200") do
          thead do
            tr do
              th(class: th_classes) { "日付" }
              th(class: th_classes) { "摘要" }
              th(class: th_classes) { "借方科目" }
              th(class: "#{th_classes} text-right") { "借方金額" }
              th(class: th_classes) { "貸方科目" }
              th(class: "#{th_classes} text-right") { "貸方金額" }
              th(class: th_classes) { "" }
            end
          end
          tbody(class: "divide-y divide-gray-100") do
            @journal_entries.each do |je|
              render_journal_entry(je)
            end
          end
        end
      end
    else
      render EmptyState.new(
        message: "仕訳がまだありません。売上や経費を登録すると自動的に仕訳が作成されます。",
        action_text: "手動仕訳を追加",
        action_path: new_fiscal_year_journal_entry_path(@fiscal_year)
      )
    end
  end

  private

  def render_journal_entry(je)
    debits = je.debit_lines
    credits = je.credit_lines
    max_lines = [ debits.size, credits.size ].max

    max_lines.times do |i|
      tr do
        if i == 0
          td(class: td_classes, rowspan: max_lines > 1 ? max_lines : nil) { je.date.to_s }
          td(class: td_classes, rowspan: max_lines > 1 ? max_lines : nil) do
            plain je.description
            unless je.manual?
              span(class: "ml-1 text-xs text-gray-400") { "(自動)" }
            end
          end
        end

        debit = debits[i]
        credit = credits[i]

        td(class: td_classes) { debit&.account&.display_name || "" }
        td(class: "#{td_classes} text-right") { debit ? format_yen(debit.amount) : "" }
        td(class: td_classes) { credit&.account&.display_name || "" }
        td(class: "#{td_classes} text-right") { credit ? format_yen(credit.amount) : "" }

        if i == 0
          td(class: "#{td_classes} text-right", rowspan: max_lines > 1 ? max_lines : nil) do
            if je.manual?
              a(href: edit_fiscal_year_journal_entry_path(@fiscal_year, je), class: "text-indigo-600 hover:text-indigo-800 text-sm") { "編集" }
            end
          end
        end
      end
    end
  end

  def format_yen(amount)
    "¥#{ActiveSupport::NumberHelper.number_to_delimited(amount)}"
  end

  def th_classes
    "px-4 py-3 text-left text-xs font-medium text-gray-500 uppercase tracking-wider"
  end

  def td_classes
    "px-4 py-3 text-sm text-gray-900"
  end
end
