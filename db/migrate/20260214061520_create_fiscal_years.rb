class CreateFiscalYears < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_years do |t|
      t.integer :year, null: false
      t.integer :filing_type, null: false, default: 0

      t.timestamps
    end

    add_index :fiscal_years, :year, unique: true
  end
end
