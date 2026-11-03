# frozen_string_literal: true

# NULL means the インボイス status isn't tracked, which is fine under 簡易課税
# and 2割特例, and new expenses now start that way. 本則課税 only credits
# expenses marked true, so an unset status never over-claims.
class AllowUnsetInvoiceStatusOnExpenses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :expenses, :invoice_eligible, true
    change_column_default :expenses, :invoice_eligible, from: true, to: nil
  end
end
