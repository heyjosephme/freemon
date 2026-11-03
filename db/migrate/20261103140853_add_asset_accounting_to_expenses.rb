# frozen_string_literal: true

# An expense is either 経費 (kind 0, deducted when paid) or 設備・資産 (kind 1),
# whose accounting_method decides how its cost is deducted over the years;
# useful_life (耐用年数) drives straight-line depreciation. Existing expenses
# stay 経費.
class AddAssetAccountingToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :kind, :integer, default: 0, null: false
    add_column :expenses, :accounting_method, :integer
    add_column :expenses, :useful_life, :integer
  end
end
