# frozen_string_literal: true

class RecurringExpensesController < ApplicationController
  before_action :set_recurring_expense, only: [ :edit, :update, :destroy, :record, :skip ]
  before_action :set_month, only: [ :record, :skip ]

  def index
    render Views::RecurringExpenses::Index.new(recurring_expenses: RecurringExpense.order(:id))
  end

  # From scratch, or 定期経費にする from an existing expense (?from_expense=ID).
  def new
    expense = Expense.find_by(id: params[:from_expense])
    @recurring_expense = expense ? RecurringExpense.from_expense(expense) : RecurringExpense.new(starts_on: Date.current)
    render Views::RecurringExpenses::New.new(recurring_expense: @recurring_expense)
  end

  def create
    @recurring_expense = RecurringExpense.new(recurring_expense_params)
    if @recurring_expense.save
      redirect_to recurring_expenses_path, notice: "定期経費を追加しました。"
    else
      render Views::RecurringExpenses::New.new(recurring_expense: @recurring_expense), status: :unprocessable_entity
    end
  end

  def edit
    render Views::RecurringExpenses::Edit.new(recurring_expense: @recurring_expense)
  end

  def update
    if @recurring_expense.update(recurring_expense_params)
      redirect_to recurring_expenses_path, notice: "定期経費を更新しました。"
    else
      render Views::RecurringExpenses::Edit.new(recurring_expense: @recurring_expense), status: :unprocessable_entity
    end
  end

  def destroy
    @recurring_expense.destroy
    redirect_to recurring_expenses_path, notice: "定期経費を削除しました。登録済みの経費はそのまま残ります。"
  end

  # 登録: saves one month's bill as an expense and goes back to that year's dashboard.
  def record
    expense = @recurring_expense.expense_for(@month, amount: params[:amount].presence || @recurring_expense.amount)
    return redirect_to(recurring_expenses_path, alert: "#{bill_name}は支払月ではありません。") unless expense

    if expense.save
      redirect_to fiscal_year_path(expense.fiscal_year), notice: "#{bill_name}を経費に登録しました。"
    else
      redirect_to fiscal_year_path(expense.fiscal_year), alert: "#{bill_name}を登録できませんでした: #{problems(expense)}"
    end
  end

  # スキップ: a month without a bill leaves the dashboard; editing the template brings it back.
  def skip
    fiscal_year = FiscalYear.find_by!(year: @month.year)
    return redirect_to(recurring_expenses_path, alert: "#{bill_name}は支払月ではありません。") unless @recurring_expense.date_in(@month)

    @recurring_expense.skip!(@month)
    redirect_to fiscal_year_path(fiscal_year), notice: "#{bill_name}をスキップしました。定期経費の編集から戻せます。"
  end

  # まとめて登録: every fixed-amount bill still open on the year's dashboard.
  def record_all
    fiscal_year = FiscalYear.find(params.expect(:fiscal_year_id))
    bills = RecurringExpense.pending_in(fiscal_year.year).select { |bill| bill.recurring_expense.fixed_amount? }
    Expense.transaction { bills.each { |bill| bill.recurring_expense.expense_for(bill.month).save! } }
    redirect_to fiscal_year_path(fiscal_year), notice: "定期経費を#{bills.size}件登録しました。"
  rescue ActiveRecord::RecordInvalid => e
    redirect_to fiscal_year_path(fiscal_year), alert: "登録できませんでした（何も保存していません）: #{e.record.description} #{problems(e.record)}"
  end

  private

  def set_recurring_expense
    @recurring_expense = RecurringExpense.find(params[:id])
  end

  def set_month
    @month = Date.iso8601(params.expect(:month)).beginning_of_month
  rescue Date::Error
    head :bad_request
  end

  def bill_name = "#{@recurring_expense.description}（#{@month.month}月分）"

  # Expense's own messages for amount are Rails' English defaults.
  def problems(expense)
    expense.errors.include?(:amount) ? "金額を1円以上で入力してください" : expense.errors.map(&:message).join("、")
  end

  def recurring_expense_params
    params.expect(recurring_expense: [ :description, :amount, :category, :business_ratio, :invoice_eligible, :purchase_channel,
                                       :interval_months, :starts_on, :ends_on, skipped_months: [] ])
  end
end
