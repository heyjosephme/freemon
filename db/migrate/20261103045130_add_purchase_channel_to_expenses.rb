# frozen_string_literal: true

# Where an expense was bought: in person (0, keep the paper receipt) or online
# (1, the receipt arrives by email). Existing expenses become in-person, the
# cautious choice: at worst they ask for a receipt that isn't needed.
class AddPurchaseChannelToExpenses < ActiveRecord::Migration[8.1]
  def change
    add_column :expenses, :purchase_channel, :integer, default: 0, null: false
  end
end
