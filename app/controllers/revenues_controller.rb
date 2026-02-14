# frozen_string_literal: true

class RevenuesController < ApplicationController
  before_action :set_fiscal_year
  before_action :set_revenue, only: [ :edit, :update, :destroy ]

  def index
    @revenues = @fiscal_year.revenues.order(date: :desc)
    render Views::Revenues::Index.new(fiscal_year: @fiscal_year, revenues: @revenues)
  end

  def new
    @revenue = @fiscal_year.revenues.build(date: Date.new(@fiscal_year.year, 1, 1))
    render Views::Revenues::New.new(fiscal_year: @fiscal_year, revenue: @revenue)
  end

  def create
    @revenue = @fiscal_year.revenues.build(revenue_params)
    if @revenue.save
      redirect_to fiscal_year_revenues_path(@fiscal_year), notice: "売上を登録しました。"
    else
      render Views::Revenues::New.new(fiscal_year: @fiscal_year, revenue: @revenue), status: :unprocessable_entity
    end
  end

  def edit
    render Views::Revenues::Edit.new(fiscal_year: @fiscal_year, revenue: @revenue)
  end

  def update
    if @revenue.update(revenue_params)
      redirect_to fiscal_year_revenues_path(@fiscal_year), notice: "売上を更新しました。"
    else
      render Views::Revenues::Edit.new(fiscal_year: @fiscal_year, revenue: @revenue), status: :unprocessable_entity
    end
  end

  def destroy
    @revenue.destroy
    redirect_to fiscal_year_revenues_path(@fiscal_year), notice: "売上を削除しました。"
  end

  private

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:fiscal_year_id])
  end

  def set_revenue
    @revenue = @fiscal_year.revenues.find(params[:id])
  end

  def revenue_params
    params.expect(revenue: [ :client_name, :amount, :date ])
  end
end
