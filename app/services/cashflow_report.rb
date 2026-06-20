# frozen_string_literal: true

# Aggregates a fiscal year's revenues and expenses into a cashflow view:
# monthly in/out with a running balance, plus revenue-by-client and
# expense-by-category breakdowns.
#
# Uses the FULL transaction amount (actual cash moved), deliberately distinct
# from the tax-deductible (家事按分後) figures used by the tax calculators.
class CashflowReport
  Month = Data.define(:month, :revenue, :expense, :net, :cumulative)
  Slice = Data.define(:label, :amount, :pct)

  attr_reader :fiscal_year

  def initialize(fiscal_year)
    @fiscal_year = fiscal_year
  end

  def months
    @months ||= begin
      revenue_by_month = sum_by_month(fiscal_year.revenues)
      expense_by_month = sum_by_month(fiscal_year.expenses)
      cumulative = 0
      (1..12).map do |m|
        revenue = revenue_by_month[m]
        expense = expense_by_month[m]
        net = revenue - expense
        cumulative += net
        Month.new(month: m, revenue: revenue, expense: expense, net: net, cumulative: cumulative)
      end
    end
  end

  def by_client
    @by_client ||= build_slices(
      fiscal_year.revenues.each_with_object(Hash.new(0)) { |r, h| h[r.client_name] += r.amount }
    )
  end

  def by_category
    @by_category ||= build_slices(
      fiscal_year.expenses.each_with_object(Hash.new(0)) { |e, h| h[Expense::CATEGORY_LABELS[e.category]] += e.amount }
    )
  end

  def totals
    @totals ||= {
      revenue: months.sum(&:revenue),
      expense: months.sum(&:expense),
      net: months.sum(&:net)
    }
  end

  private

  def sum_by_month(records)
    records.each_with_object(Hash.new(0)) { |r, h| h[r.date.month] += r.amount }
  end

  def build_slices(totals_by_label)
    grand_total = totals_by_label.values.sum
    return [] if grand_total.zero?

    totals_by_label
      .sort_by { |_label, amount| -amount }
      .map { |label, amount| Slice.new(label: label, amount: amount, pct: (amount * 100.0 / grand_total).round(1)) }
  end
end
