class CreateRevenues < ActiveRecord::Migration[8.1]
  def change
    create_table :revenues do |t|
      t.references :fiscal_year, null: false, foreign_key: true
      t.string :client_name, null: false
      t.integer :amount, null: false
      t.date :date, null: false

      t.timestamps
    end
  end
end
