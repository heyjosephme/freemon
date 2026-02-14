class CreateJournalEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :journal_entries do |t|
      t.references :fiscal_year, null: false, foreign_key: true
      t.date :date, null: false
      t.string :description, null: false
      t.string :source_type
      t.integer :source_id

      t.timestamps
    end

    add_index :journal_entries, [ :source_type, :source_id ], unique: true, where: "source_type IS NOT NULL"
    add_index :journal_entries, [ :fiscal_year_id, :date ]
  end
end
