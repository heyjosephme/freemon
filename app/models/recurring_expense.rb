# frozen_string_literal: true

# 定期経費: a bill that comes back on the same day every month, every two months
# or every year (家賃, 通信費, 水道光熱費), kept as a template for the expenses
# recorded from it. A blank amount means the bill varies and is typed in each time.
#
# Nothing posts by itself: the dashboard lists each bill that's due and neither
# recorded nor skipped, and recording one saves an ordinary expense in that
# month's fiscal year. Editing a template leaves recorded expenses alone.
class RecurringExpense < ApplicationRecord
  INTERVALS = { 1 => "毎月", 2 => "2か月ごと", 12 => "毎年" }.freeze

  # One payment that's due: the template and the date it falls on.
  Bill = Data.define(:recurring_expense, :date) do
    def month = date.beginning_of_month
  end

  has_many :expenses

  enum :category, Expense.categories, default: :other
  # Bills come by bank transfer, card or e-mail, without a paper receipt to photograph.
  enum :purchase_channel, Expense.purchase_channels, default: :online

  before_validation :tidy_skipped_months
  before_destroy :unlink_expenses

  validates :description, presence: { message: "内容を入力してください" }
  validates :amount, allow_nil: true,
                     numericality: { greater_than: 0, only_integer: true, message: "金額は1円以上で入力してください（毎回変わるなら空欄）" }
  validates :business_ratio, numericality: { in: 1..100, only_integer: true, message: "家事按分率は1〜100で入力してください" }
  validates :interval_months, inclusion: { in: INTERVALS.keys, message: "間隔を選んでください" }
  validates :starts_on, presence: { message: "初回の支払日を入力してください" }
  validate :ends_after_it_starts

  # Every template's bills due in the year up to the end of this month that are
  # neither recorded nor skipped, oldest first.
  def self.pending_in(year, through: Date.current.end_of_month)
    all.flat_map { |template| template.pending_in(year, through:) }.sort_by { |bill| [ bill.date, bill.recurring_expense.description ] }
  end

  # 定期経費にする: a template copied from an expense. It's first due on the expense's
  # day of the month, after both the expense and today, so months already entered by
  # hand don't come up as missing.
  def self.from_expense(expense, today: Date.current)
    months = 1
    months += 1 while (expense.date >> months) < today
    new(expense.slice(:description, :category, :amount, :business_ratio, :invoice_eligible, :purchase_channel)
               .merge(starts_on: expense.date >> months))
  end

  def pending_in(year, through: Date.current.end_of_month)
    recorded = expenses.where(recurring_month: Date.new(year).all_year).pluck(:recurring_month)
    dates_in(year)
      .select { |date| date <= through }
      .reject { |date| recorded.include?(date.beginning_of_month) || skipped?(date) }
      .map { |date| Bill.new(self, date) }
  end

  # Its payment dates in the year: starts_on, then every interval_months months on
  # the same day (the month's last day when it's shorter), up to ends_on.
  def dates_in(year)
    last = [ Date.new(year, 12, 31), ends_on ].compact.min
    payment_dates.take_while { |date| date <= last }.select { |date| date.year == year }.to_a
  end

  # The payment date in the given month, or nil when nothing is due then.
  def date_in(month) = dates_in(month.year).find { |date| date.beginning_of_month == month.beginning_of_month }

  # The month's bill as a new expense in its fiscal year: this template's details, the
  # payment date, and the amount (the template's own unless given). Nil when nothing's due.
  def expense_for(month, amount: self.amount)
    date = date_in(month) or return

    FiscalYear.find_by!(year: date.year).expenses.build(
      description:, category:, business_ratio:, invoice_eligible:, purchase_channel:, amount:, date:,
      recurring_expense: self, recurring_month: date.beginning_of_month
    )
  end

  def skipped?(date) = skipped_months.include?(date.beginning_of_month.iso8601)

  def skip!(month) = update!(skipped_months: skipped_months + [ month.beginning_of_month.iso8601 ])

  def fixed_amount? = amount.present?

  def ended? = ends_on.present? && ends_on < Date.current

  # "毎月27日", "2か月ごと（偶数月）10日", "毎年4月1日". A schedule that starts on
  # the 31st falls on the last day of every month.
  def schedule_label
    day = starts_on.day == 31 ? "末日" : "#{starts_on.day}日"
    case interval_months
    when 1 then "毎月#{day}"
    when 2 then "2か月ごと（#{starts_on.month.even? ? "偶数月" : "奇数月"}）#{day}"
    else "毎年#{starts_on.month}月#{day}"
    end
  end

  # "2026年4月〜", or "2026年4月〜2027年3月" once it has an end.
  def period_label = [ starts_on, ends_on ].map { |date| date && "#{date.year}年#{date.month}月" }.join("〜")

  private

  def payment_dates = Enumerator.produce(0) { |months| months + interval_months }.lazy.map { |months| starts_on >> months }

  # The 1st of each month as an ISO date, sorted, dropping blanks and anything that isn't a date.
  def tidy_skipped_months
    self.skipped_months = Array(skipped_months).filter_map { |value| first_of_month(value) }.uniq.sort
  end

  def first_of_month(value)
    Date.iso8601(value.to_s).beginning_of_month.iso8601
  rescue Date::Error
    nil
  end

  def ends_after_it_starts
    errors.add(:ends_on, "終了日は初回の支払日より後にしてください") if starts_on && ends_on && ends_on < starts_on
  end

  # Recorded expenses stay; they just stop pointing here.
  def unlink_expenses
    expenses.update_all(recurring_expense_id: nil, recurring_month: nil)
  end
end
