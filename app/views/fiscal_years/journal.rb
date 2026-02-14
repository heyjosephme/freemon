# frozen_string_literal: true

class Views::FiscalYears::Journal < Views::Base
  def initialize(fiscal_year:, journal_entries:)
    @fiscal_year = fiscal_year
    @journal_entries = journal_entries
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 仕訳帳 (Journal)", back_path: fiscal_year_path(@fiscal_year))

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
            end
          end
          tbody(class: "divide-y divide-gray-200") do
            @journal_entries.each do |je|
              render_entry(je)
            end
          end
        end
      end
    else
      render EmptyState.new(message: "仕訳データがありません。")
    end
  end

  private

  def render_entry(je)
    debits = je.debit_lines
    credits = je.credit_lines
    max = [ debits.size, credits.size ].max

    max.times do |i|
      tr(class: i == 0 ? "border-t-2 border-gray-300" : "") do
        td(class: td_classes) { i == 0 ? je.date.to_s : "" }
        td(class: td_classes) { i == 0 ? je.description : "" }
        td(class: td_classes) { debits[i]&.account&.display_name || "" }
        td(class: "#{td_classes} text-right") { debits[i] ? format_yen(debits[i].amount) : "" }
        td(class: td_classes) { credits[i]&.account&.display_name || "" }
        td(class: "#{td_classes} text-right") { credits[i] ? format_yen(credits[i].amount) : "" }
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
    "px-4 py-2 text-sm text-gray-900"
  end
end
