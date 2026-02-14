# frozen_string_literal: true

class Views::JournalEntries::New < Views::Base
  def initialize(fiscal_year:, journal_entry:)
    @fiscal_year = fiscal_year
    @journal_entry = journal_entry
  end

  def view_template
    render PageHeader.new(title: "手動仕訳の追加", back_path: fiscal_year_journal_entries_path(@fiscal_year))
    render Views::JournalEntries::Form.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry)
  end
end
