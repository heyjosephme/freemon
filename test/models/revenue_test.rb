# frozen_string_literal: true

require "test_helper"

class RevenueTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "a copy is dated a month later, and a month-end date stays at month-end" do
    { Date.new(2030, 7, 15) => Date.new(2030, 8, 15), Date.new(2030, 9, 30) => Date.new(2030, 10, 31),
      Date.new(2030, 1, 31) => Date.new(2030, 2, 28), Date.new(2030, 2, 28) => Date.new(2030, 3, 31),
      Date.new(2030, 12, 31) => Date.new(2031, 1, 31) }.each do |date, copied|
      assert_equal copied, @fiscal_year.revenues.build(client_name: "A", amount: 1, date: date).next_month_date, date
    end
  end

  test "December's copy belongs in the next fiscal year, once it has been started" do
    november = @fiscal_year.revenues.create!(client_name: "A", amount: 1_000, date: Date.new(2030, 11, 30))
    december = @fiscal_year.revenues.create!(client_name: "A", amount: 1_000, date: Date.new(2030, 12, 31))

    assert_equal @fiscal_year, november.next_month_fiscal_year
    assert_nil december.next_month_fiscal_year

    following = FiscalYear.create!(year: 2031)
    assert_equal following, december.next_month_fiscal_year
  end
end
