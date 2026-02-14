# frozen_string_literal: true

class DeductionsController < ApplicationController
  before_action :set_fiscal_year
  before_action :set_deduction, only: [ :edit, :update, :destroy ]

  def index
    @deductions = @fiscal_year.deductions.order(:deduction_type)
    render Views::Deductions::Index.new(fiscal_year: @fiscal_year, deductions: @deductions)
  end

  def new
    @deduction = @fiscal_year.deductions.build
    render Views::Deductions::New.new(fiscal_year: @fiscal_year, deduction: @deduction)
  end

  def create
    @deduction = @fiscal_year.deductions.build(deduction_params)
    if @deduction.save
      redirect_to fiscal_year_deductions_path(@fiscal_year), notice: "控除を登録しました。"
    else
      render Views::Deductions::New.new(fiscal_year: @fiscal_year, deduction: @deduction), status: :unprocessable_entity
    end
  end

  def edit
    render Views::Deductions::Edit.new(fiscal_year: @fiscal_year, deduction: @deduction)
  end

  def update
    if @deduction.update(deduction_params)
      redirect_to fiscal_year_deductions_path(@fiscal_year), notice: "控除を更新しました。"
    else
      render Views::Deductions::Edit.new(fiscal_year: @fiscal_year, deduction: @deduction), status: :unprocessable_entity
    end
  end

  def destroy
    @deduction.destroy
    redirect_to fiscal_year_deductions_path(@fiscal_year), notice: "控除を削除しました。"
  end

  private

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:fiscal_year_id])
  end

  def set_deduction
    @deduction = @fiscal_year.deductions.find(params[:id])
  end

  def deduction_params
    params.expect(deduction: [ :deduction_type, :amount ])
  end
end
