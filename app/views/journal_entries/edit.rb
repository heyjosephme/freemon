# frozen_string_literal: true

class Views::JournalEntries::Edit < Views::Base
  def initialize(fiscal_year:, journal_entry:)
    @fiscal_year = fiscal_year
    @journal_entry = journal_entry
  end

  def view_template
    render PageHeader.new(title: "仕訳の編集", back_path: fiscal_year_journal_entries_path(@fiscal_year))
    render Views::JournalEntries::Form.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry)
  end
end
