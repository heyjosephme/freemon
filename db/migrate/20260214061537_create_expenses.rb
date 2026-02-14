class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :fiscal_year, null: false, foreign_key: true
      t.string :description, null: false
      t.integer :amount, null: false
      t.integer :category, null: false, default: 6
      t.integer :business_ratio, null: false, default: 100
      t.boolean :invoice_eligible, null: false, default: true
      t.date :date, null: false

      t.timestamps
    end
  end
end
