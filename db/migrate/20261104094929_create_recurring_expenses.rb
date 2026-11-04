# frozen_string_literal: true

# 定期経費: bills that come back on the same day every month or so (家賃,
# 通信費, 水道光熱費), kept as templates for the expenses recorded from them.
class CreateRecurringExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :recurring_expenses do |t|
      t.string :description, null: false
      t.integer :category, null: false, default: 6
      t.integer :amount
      t.integer :business_ratio, null: false, default: 100
      t.boolean :invoice_eligible
      t.integer :purchase_channel, null: false, default: 1
      t.integer :interval_months, null: false, default: 1
      t.date :starts_on, null: false
      t.date :ends_on
      t.json :skipped_months, null: false, default: []
      t.timestamps
    end
  end
end
