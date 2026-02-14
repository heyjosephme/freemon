class CreateJournalEntryLines < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entry_lines do |t|
      t.references :journal_entry, null: false, foreign_key: true
      t.references :account, null: false, foreign_key: true
      t.integer :side, null: false
      t.integer :amount, null: false

      t.timestamps
    end
  end
end
