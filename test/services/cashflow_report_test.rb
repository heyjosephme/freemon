# frozen_string_literal: true

require "test_helper"

class CashflowReportTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
    @fiscal_year.revenues.create!(client_name: "Client A", amount: 300_000, date: Date.new(2099, 1, 15))
    @fiscal_year.revenues.create!(client_name: "Client A", amount: 200_000, date: Date.new(2099, 3, 10))
    @fiscal_year.revenues.create!(client_name: "Client B", amount: 600_000, date: Date.new(2099, 3, 20))
    @fiscal_year.expenses.create!(description: "Laptop", amount: 100_000, category: :equipment, business_ratio: 50, date: Date.new(2099, 1, 5))
    @fiscal_year.expenses.create!(description: "Coworking", amount: 60_000, category: :office, business_ratio: 100, date: Date.new(2099, 3, 1))
    @report = CashflowReport.new(@fiscal_year)
  end

  test "months returns 12 buckets with a running cumulative balance" do
    months = @report.months
    assert_equal 12, months.length

    jan = months[0]
    assert_equal 300_000, jan.revenue
    assert_equal 200_000, jan.net
    assert_equal 200_000, jan.cumulative

    mar = months[2]
    assert_equal 800_000, mar.revenue
    assert_equal 60_000, mar.expense
    assert_equal 740_000, mar.net
    assert_equal 940_000, mar.cumulative # 200,000 (Jan) + 740,000 (Mar)

    assert_equal 940_000, months.last.cumulative
  end

  test "expense uses the full amount (actual cash), ignoring 家事按分" do
    # Jan laptop is ¥100,000 at 50% business ratio; cashflow shows the full ¥100,000.
    assert_equal 100_000, @report.months[0].expense
  end

  test "by_client aggregates, sorts descending, and computes percentages" do
    slices = @report.by_client
    assert_equal [ "Client B", "Client A" ], slices.map(&:label)
    assert_equal [ 600_000, 500_000 ], slices.map(&:amount)
    assert_in_delta 54.5, slices[0].pct, 0.1
    assert_in_delta 45.5, slices[1].pct, 0.1
  end

  test "by_category uses human labels, sorts descending, and computes percentages" do
    slices = @report.by_category
    assert_equal [ 100_000, 60_000 ], slices.map(&:amount)
    assert_equal Expense::CATEGORY_LABELS["equipment"], slices[0].label
    assert_in_delta 62.5, slices[0].pct, 0.01
    assert_in_delta 37.5, slices[1].pct, 0.01
  end

  test "totals sum revenue, expense and net" do
    assert_equal({ revenue: 1_100_000, expense: 160_000, net: 940_000 }, @report.totals)
  end

  test "empty fiscal year yields zero totals and empty breakdowns" do
    empty = CashflowReport.new(FiscalYear.create!(year: 2098, filing_type: :white))
    assert_equal({ revenue: 0, expense: 0, net: 0 }, empty.totals)
    assert_empty empty.by_client
    assert_empty empty.by_category
    assert_equal 12, empty.months.length
  end
end
