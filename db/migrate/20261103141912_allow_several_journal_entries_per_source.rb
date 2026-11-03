# frozen_string_literal: true

# An asset spread over years has a purchase entry plus one 減価償却 entry per
# year, so a source can no longer be unique. JournalEntrySync clears a
# source's entries before posting them, which keeps them from piling up.
class AllowSeveralJournalEntriesPerSource < ActiveRecord::Migration[8.1]
  def change
    remove_index :journal_entries, [ :source_type, :source_id ], unique: true, where: "source_type IS NOT NULL"
    add_index :journal_entries, [ :source_type, :source_id ]
  end
end
