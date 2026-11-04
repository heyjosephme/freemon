# frozen_string_literal: true

# Links an expense to the 定期経費 it was recorded from and the month it pays,
# so each month is recorded at most once.
class AddRecurringExpenseToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_reference :expenses, :recurring_expense, foreign_key: true, index: false
    add_column :expenses, :recurring_month, :date
    add_index :expenses, [ :recurring_expense_id, :recurring_month ], unique: true
  end
end
