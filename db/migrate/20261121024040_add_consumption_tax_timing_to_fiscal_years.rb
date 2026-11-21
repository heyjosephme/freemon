# frozen_string_literal: true

# When a year's 消費税 becomes 租税公課: 0 accrued at year-end as 未払金 (the default),
# 1 in the following year when it's paid. Existing years get their 消費税 journal
# entries here, so the 損益計算書 matches the dashboard without waiting for the next save.
class AddConsumptionTaxTimingToFiscalYears < ActiveRecord::Migration[8.1]
  def up
    add_column :fiscal_years, :consumption_tax_timing, :integer, default: 0, null: false

    FiscalYear.reset_column_information
    FiscalYear.order(:year).each { |fiscal_year| JournalEntrySync.sync(fiscal_year) } if Account.exists?
  end

  def down
    JournalEntry.where(source_type: "FiscalYear").destroy_all
    remove_column :fiscal_years, :consumption_tax_timing
  end
end
