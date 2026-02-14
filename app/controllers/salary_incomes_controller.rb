# frozen_string_literal: true

class SalaryIncomesController < ApplicationController
  before_action :set_fiscal_year
  before_action :set_salary_income, only: [ :show, :edit, :update, :destroy ]

  def show
    render Views::SalaryIncomes::Show.new(fiscal_year: @fiscal_year, salary_income: @salary_income)
  end

  def new
    if @fiscal_year.salary_income
      redirect_to edit_fiscal_year_salary_income_path(@fiscal_year)
      return
    end
    @salary_income = @fiscal_year.build_salary_income
    render Views::SalaryIncomes::New.new(fiscal_year: @fiscal_year, salary_income: @salary_income)
  end

  def create
    @salary_income = @fiscal_year.build_salary_income(salary_income_params)
    if @salary_income.save
      redirect_to fiscal_year_path(@fiscal_year), notice: "給与情報を登録しました。"
    else
      render Views::SalaryIncomes::New.new(fiscal_year: @fiscal_year, salary_income: @salary_income), status: :unprocessable_entity
    end
  end

  def edit
    render Views::SalaryIncomes::Edit.new(fiscal_year: @fiscal_year, salary_income: @salary_income)
  end

  def update
    if @salary_income.update(salary_income_params)
      redirect_to fiscal_year_path(@fiscal_year), notice: "給与情報を更新しました。"
    else
      render Views::SalaryIncomes::Edit.new(fiscal_year: @fiscal_year, salary_income: @salary_income), status: :unprocessable_entity
    end
  end

  def destroy
    @salary_income.destroy
    redirect_to fiscal_year_path(@fiscal_year), notice: "給与情報を削除しました。"
  end

  private

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:fiscal_year_id])
  end

  def set_salary_income
    @salary_income = @fiscal_year.salary_income or raise ActiveRecord::RecordNotFound
  end

  def salary_income_params
    params.expect(salary_income: [ :gross_salary, :tax_withheld, :social_insurance ])
  end
end
