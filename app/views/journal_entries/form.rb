# frozen_string_literal: true

class Views::JournalEntries::Form < Views::Base
  def initialize(fiscal_year:, journal_entry:)
    @fiscal_year = fiscal_year
    @journal_entry = journal_entry
    @accounts = Account.ordered
  end

  def view_template
    url = @journal_entry.persisted? ? fiscal_year_journal_entry_path(@fiscal_year, @journal_entry) : fiscal_year_journal_entries_path(@fiscal_year)

    form_with(model: @journal_entry, url: url, class: "space-y-6", data: { controller: "journal-entry-form" }) do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :date, "日付 (Date)", class: LABEL
          f.date_field :date, class: input_classes
          errors_for(f, :date)
        end

        div(class: "mb-4") do
          f.label :description, "摘要 (Description)", class: LABEL
          f.text_field :description, class: input_classes, placeholder: "取引の内容"
          errors_for(f, :description)
        end

        @journal_entry.errors[:base].each do |error|
          p(class: "text-sm text-negative mb-2") { error }
        end
      end

      render Card.new(title: "仕訳明細 (Entry Lines)") do
        div(data: { "journal-entry-form-target": "lines" }) do
          f.fields_for :lines do |lf|
            render_line_fields(lf)
          end
        end

        div(class: "mt-4") do
          button(type: "button", class: "text-sm #{LINK}",
            data: { action: "journal-entry-form#addLine" }) { "＋ 行を追加" }
        end

        # Balance indicator
        div(class: "mt-4 pt-4 border-t text-sm",
          data: { "journal-entry-form-target": "balance" }) do
          plain "借方・貸方の合計が一致する必要があります。"
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@journal_entry.persisted? ? "更新" : "登録",
            class: Button.classes)
          a(href: fiscal_year_journal_entries_path(@fiscal_year),
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end

    # Template for adding new lines via Stimulus
    template(data: { "journal-entry-form-target": "template" }) do
      render_line_template
    end
  end

  private

  def render_line_fields(lf)
    div(class: "flex gap-3 items-end mb-3 line-fields") do
      div(class: "flex-1") do
        lf.label :account_id, "勘定科目", class: "block text-xs text-muted mb-1"
        lf.select :account_id, account_options, { include_blank: "選択..." }, class: input_classes_sm
      end

      div(class: "w-28") do
        lf.label :side, "借/貸", class: "block text-xs text-muted mb-1"
        lf.select :side, [ [ "借方 (Debit)", "debit" ], [ "貸方 (Credit)", "credit" ] ], {}, class: input_classes_sm
      end

      div(class: "w-32") do
        lf.label :amount, "金額", class: "block text-xs text-muted mb-1"
        lf.number_field :amount, min: 1, class: input_classes_sm, placeholder: "¥",
          data: { action: "input->journal-entry-form#updateBalance" }
      end

      div(class: "pb-1") do
        lf.check_box :_destroy, class: "hidden"
        button(type: "button", class: "text-muted hover:text-negative cursor-pointer text-sm",
          data: { action: "journal-entry-form#removeLine" }) { "✕" }
      end
    end
  end

  def render_line_template
    # Plain HTML template for new lines (Stimulus will clone and inject this)
    div(class: "flex gap-3 items-end mb-3 line-fields") do
      div(class: "flex-1") do
        label(class: "block text-xs text-muted mb-1") { "勘定科目" }
        select(name: "journal_entry[lines_attributes][NEW_IDX][account_id]", class: input_classes_sm) do
          option(value: "") { "選択..." }
          account_options.each do |label_text, val|
            option(value: val) { label_text }
          end
        end
      end

      div(class: "w-28") do
        label(class: "block text-xs text-muted mb-1") { "借/貸" }
        select(name: "journal_entry[lines_attributes][NEW_IDX][side]", class: input_classes_sm) do
          option(value: "debit") { "借方 (Debit)" }
          option(value: "credit") { "貸方 (Credit)" }
        end
      end

      div(class: "w-32") do
        label(class: "block text-xs text-muted mb-1") { "金額" }
        input(type: "number", name: "journal_entry[lines_attributes][NEW_IDX][amount]", min: 1, class: input_classes_sm, placeholder: "¥",
          data: { action: "input->journal-entry-form#updateBalance" })
      end

      div(class: "pb-1") do
        button(type: "button", class: "text-muted hover:text-negative cursor-pointer text-sm",
          data: { action: "journal-entry-form#removeLine" }) { "✕" }
      end
    end
  end

  def account_options
    @accounts.map { |a| [ a.display_name_with_en, a.id ] }
  end

  def errors_for(f, field)
    @journal_entry.errors[field].each do |error|
      p(class: "mt-1 text-sm text-negative") { error }
    end
  end

  def input_classes
    "block w-full #{INPUT}"
  end

  def input_classes_sm
    "block w-full rounded-md border-0 bg-surface py-1 px-2 text-sm text-ink ring-1 ring-inset ring-line-strong outline-none focus:ring-2 focus:ring-primary"
  end
end
