# frozen_string_literal: true

require "test_helper"

class RecurringExpenseTest < ActiveSupport::TestCase
  setup do
    @fiscal_year = FiscalYear.create!(year: 2030)
  end

  test "a monthly bill falls on its day each month, and on the last day of shorter months" do
    rent = create_template(starts_on: Date.new(2030, 1, 31))

    assert_equal [ 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 ], rent.dates_in(2030).map(&:day)
    assert_equal "毎月末日", rent.schedule_label
  end

  test "bills can come every two months or once a year, counted from the month they start" do
    water = create_template(interval_months: 2, starts_on: Date.new(2029, 12, 10))
    assert_equal [ 2, 4, 6, 8, 10, 12 ], water.dates_in(2030).map(&:month)
    assert_equal "2か月ごと（偶数月）10日", water.schedule_label

    domain = create_template(interval_months: 12, starts_on: Date.new(2028, 4, 1))
    assert_equal [ Date.new(2030, 4, 1) ], domain.dates_in(2030)
    assert_equal "毎年4月1日", domain.schedule_label
  end

  test "nothing is due before it starts or after it ends" do
    internet = create_template(starts_on: Date.new(2030, 4, 27), ends_on: Date.new(2030, 9, 30))

    assert_equal (4..9).to_a, internet.dates_in(2030).map(&:month)
    assert_empty internet.dates_in(2029)
    assert_empty internet.dates_in(2031)
    assert_equal "2030年4月〜2030年9月", internet.period_label
  end

  test "pending bills are the year's months through this one that are neither recorded nor skipped" do
    rent = create_template(starts_on: Date.new(2030, 1, 27))
    rent.expense_for(Date.new(2030, 3, 1)).save!
    rent.skip!(Date.new(2030, 4, 1))

    travel_to Date.new(2030, 6, 3) do
      assert_equal [ 1, 2, 5, 6 ], rent.pending_in(2030).map { |bill| bill.month.month }
      assert_equal Date.new(2030, 6, 27), rent.pending_in(2030).last.date, "this month's bill shows before its day"
      assert_empty rent.pending_in(2031)
    end
  end

  test "every template's pending bills come oldest first" do
    rent = create_template(description: "家賃", starts_on: Date.new(2030, 5, 27))
    power = create_template(description: "電気", amount: nil, starts_on: Date.new(2030, 5, 26))

    travel_to Date.new(2030, 6, 1) do
      assert_equal [ [ power, 5 ], [ rent, 5 ], [ power, 6 ], [ rent, 6 ] ],
                   RecurringExpense.pending_in(2030).map { |bill| [ bill.recurring_expense, bill.month.month ] }
    end
  end

  test "skipped months are kept as the 1st of each month, without blanks or anything that isn't a date" do
    rent = create_template(starts_on: Date.new(2030, 1, 27))
    rent.update!(skipped_months: [ "", "2030-04-15", "nonsense", "2030-02-01", "2030-04-01" ])

    assert_equal [ "2030-02-01", "2030-04-01" ], rent.skipped_months
  end

  test "recording copies the template into the month's fiscal year" do
    rent = create_template(description: "家賃", amount: 120_000, category: :office, business_ratio: 30, invoice_eligible: false,
                           starts_on: Date.new(2030, 1, 27))

    expense = rent.expense_for(Date.new(2030, 3, 1))
    expense.save!

    assert_equal [ @fiscal_year, "家賃", 120_000, "office", 30, false, "online", Date.new(2030, 3, 27), Date.new(2030, 3, 1) ],
                 [ expense.fiscal_year, expense.description, expense.amount, expense.category, expense.business_ratio,
                   expense.invoice_eligible, expense.purchase_channel, expense.date, expense.recurring_month ]
    assert_nil rent.expense_for(Date.new(2029, 12, 1)), "not due before it starts"
  end

  test "a varying bill takes its amount each time, and a month can only be recorded once" do
    power = create_template(description: "電気", amount: nil, category: :utilities, starts_on: Date.new(2030, 1, 26))

    assert_not power.expense_for(Date.new(2030, 1, 1)).valid?
    assert power.expense_for(Date.new(2030, 1, 1), amount: 8_200).save

    again = power.expense_for(Date.new(2030, 1, 1), amount: 8_200)
    assert_not again.save
    assert_equal [ "この月の分はもう登録されています" ], again.errors[:recurring_month]
  end

  test "deleting a template keeps the expenses recorded from it" do
    rent = create_template(starts_on: Date.new(2030, 1, 27))
    expense = rent.expense_for(Date.new(2030, 1, 1))
    expense.save!

    rent.destroy!

    expense.reload
    assert_nil expense.recurring_expense_id
    assert_nil expense.recurring_month
  end

  test "a template copied from an expense is first due after both the expense and today" do
    expense = @fiscal_year.expenses.create!(description: "家賃", amount: 120_000, category: :office, business_ratio: 30,
                                            date: Date.new(2030, 6, 27))

    copy = RecurringExpense.from_expense(expense, today: Date.new(2030, 11, 4))
    assert_equal [ "家賃", 120_000, "office", 30, Date.new(2030, 11, 27) ],
                 [ copy.description, copy.amount, copy.category, copy.business_ratio, copy.starts_on ]
    assert_equal Date.new(2030, 7, 27), RecurringExpense.from_expense(expense, today: Date.new(2030, 6, 28)).starts_on
  end

  test "amount, 按分率, interval and dates must make sense" do
    assert template(amount: nil).valid?, "a blank amount means it varies"
    assert_not template(amount: 0).valid?
    assert_not template(business_ratio: 0).valid?
    assert_not template(interval_months: 3).valid?

    ends_early = template(starts_on: Date.new(2030, 5, 1), ends_on: Date.new(2030, 4, 30))
    assert_not ends_early.valid?
    assert_equal [ "終了日は初回の支払日より後にしてください" ], ends_early.errors[:ends_on]
  end

  private

  def template(**attributes)
    RecurringExpense.new({ description: "家賃", amount: 100_000, category: :office, starts_on: Date.new(2030, 1, 1) }.merge(attributes))
  end

  def create_template(**attributes) = template(**attributes).tap(&:save!)
end
