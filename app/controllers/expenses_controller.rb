# frozen_string_literal: true

class ExpensesController < ApplicationController
  before_action :set_fiscal_year
  before_action :set_expense, only: [ :edit, :update, :destroy ]

  def index
    @expenses = @fiscal_year.expenses.order(date: :desc)
    render Views::Expenses::Index.new(fiscal_year: @fiscal_year, expenses: @expenses)
  end

  def new
    @expense = @fiscal_year.expenses.build(date: Date.new(@fiscal_year.year, 1, 1), business_ratio: 100, invoice_eligible: true)
    render Views::Expenses::New.new(fiscal_year: @fiscal_year, expense: @expense)
  end

  def create
    @expense = @fiscal_year.expenses.build(expense_params)
    if @expense.save
      redirect_to fiscal_year_expenses_path(@fiscal_year), notice: "経費を登録しました。"
    else
      render Views::Expenses::New.new(fiscal_year: @fiscal_year, expense: @expense), status: :unprocessable_entity
    end
  end

  def edit
    render Views::Expenses::Edit.new(fiscal_year: @fiscal_year, expense: @expense)
  end

  def update
    if @expense.update(expense_params)
      redirect_to fiscal_year_expenses_path(@fiscal_year), notice: "経費を更新しました。"
    else
      render Views::Expenses::Edit.new(fiscal_year: @fiscal_year, expense: @expense), status: :unprocessable_entity
    end
  end

  def destroy
    @expense.destroy
    redirect_to fiscal_year_expenses_path(@fiscal_year), notice: "経費を削除しました。"
  end

  private

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:fiscal_year_id])
  end

  def set_expense
    @expense = @fiscal_year.expenses.find(params[:id])
  end

  def expense_params
    params.expect(expense: [ :description, :amount, :category, :business_ratio, :invoice_eligible, :date ])
  end
end
