class AddBusinessProfitTargetToFiscalYears < ActiveRecord::Migration[8.1]
  def change
    add_column :fiscal_years, :business_profit_target, :integer
  end
end
