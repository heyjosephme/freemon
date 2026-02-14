class CreateDeductions < ActiveRecord::Migration[8.1]
  def change
    create_table :deductions do |t|
      t.references :fiscal_year, null: false, foreign_key: true
      t.integer :deduction_type, null: false
      t.integer :amount, null: false

      t.timestamps
    end
  end
end
