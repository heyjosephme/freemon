# frozen_string_literal: true

# Revenues from a CSV with the columns 日付,取引先,金額 (tax-included):
#
#   日付,取引先,金額
#   2026-07-31,株式会社テックコープ,"¥550,000"
#
# See CsvImport for how files are read and saved.
class RevenueImport < CsvImport
  MODEL = Revenue
  IDENTITY = %i[date client_name amount].freeze
  COLUMNS = {
    date: { names: [ "日付", "date" ], required: true },
    client_name: { names: [ "取引先", "取引先名", "client", "client_name" ], required: true },
    amount: { names: [ "金額", "金額(税込)", "amount" ], required: true }
  }.freeze

  def describe(row)
    format("%s  %12s  %s", row[:date], yen(row[:amount]), row[:client_name])
  end

  private

  def attributes_for(values, errors)
    {
      date: date_value(values[:date], errors),
      client_name: text_value(values[:client_name], "取引先", errors),
      amount: amount_value(values[:amount], errors)
    }
  end
end
