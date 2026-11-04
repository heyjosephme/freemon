# frozen_string_literal: true

class FiscalYearsController < ApplicationController
  before_action :set_fiscal_year, only: [ :show, :edit, :update, :destroy, :tax_summary, :journal, :general_ledger, :income_statement, :balance_sheet, :depreciation, :cashflow, :tax_reserve, :tax_saving ]

  def index
    @fiscal_years = FiscalYear.order(year: :desc)
    render Views::FiscalYears::Index.new(fiscal_years: @fiscal_years)
  end

  def current
    fiscal_year = FiscalYear.home
    redirect_to fiscal_year ? fiscal_year_path(fiscal_year) : new_fiscal_year_path
  end

  def show
    render Views::FiscalYears::Show.new(
      fiscal_year: @fiscal_year,
      reserve: TaxReserveEstimator.new(@fiscal_year).calculate,
      filing_year: open_filing_year,
      start_current_year: start_current_year?,
      recurring_bills: RecurringExpense.pending_in(@fiscal_year.year)
    )
  end

  def new
    @fiscal_year = FiscalYear.new(year: FiscalYear.suggested_new_year, filing_type: FiscalYear.latest&.filing_type || :blue_65)
    render Views::FiscalYears::New.new(fiscal_year: @fiscal_year)
  end

  def create
    @fiscal_year = FiscalYear.new(fiscal_year_params)
    if @fiscal_year.save
      redirect_to @fiscal_year, notice: "確定申告年度を作成しました。"
    else
      render Views::FiscalYears::New.new(fiscal_year: @fiscal_year), status: :unprocessable_entity
    end
  end

  def edit
    render Views::FiscalYears::Edit.new(fiscal_year: @fiscal_year)
  end

  def update
    if @fiscal_year.update(fiscal_year_params)
      redirect_to @fiscal_year, notice: "確定申告年度を更新しました。"
    else
      render Views::FiscalYears::Edit.new(fiscal_year: @fiscal_year), status: :unprocessable_entity
    end
  end

  def destroy
    @fiscal_year.destroy
    redirect_to fiscal_years_path, notice: "確定申告年度を削除しました。"
  end

  def journal
    entries = @fiscal_year.journal_entries.includes(lines: :account).chronological
    render Views::FiscalYears::Journal.new(fiscal_year: @fiscal_year, journal_entries: entries)
  end

  def general_ledger
    @account = params[:account_id].present? ? Account.find(params[:account_id]) : Account.ordered.first
    entries = @fiscal_year.journal_entries
      .joins(:lines).where(journal_entry_lines: { account_id: @account&.id })
      .includes(lines: :account).distinct.chronological
    render Views::FiscalYears::GeneralLedger.new(
      fiscal_year: @fiscal_year, account: @account, journal_entries: entries, accounts: Account.ordered
    )
  end

  def income_statement
    render Views::FiscalYears::IncomeStatement.new(fiscal_year: @fiscal_year)
  end

  def balance_sheet
    render Views::FiscalYears::BalanceSheet.new(fiscal_year: @fiscal_year)
  end

  def depreciation
    render Views::FiscalYears::Depreciation.new(fiscal_year: @fiscal_year, assets: @fiscal_year.depreciation_table_assets)
  end

  def tax_summary
    income_tax = IncomeTaxCalculator.new(@fiscal_year).calculate
    consumption_tax = ConsumptionTaxCalculator.new(@fiscal_year).calculate
    render Views::FiscalYears::TaxSummary.new(
      fiscal_year: @fiscal_year,
      income_tax: income_tax,
      consumption_tax: consumption_tax
    )
  end

  def cashflow
    render Views::FiscalYears::Cashflow.new(
      fiscal_year: @fiscal_year,
      report: CashflowReport.new(@fiscal_year)
    )
  end

  def tax_reserve
    render Views::FiscalYears::TaxReserve.new(
      fiscal_year: @fiscal_year,
      reserve: TaxReserveEstimator.new(@fiscal_year).calculate
    )
  end

  def tax_saving
    render Views::FiscalYears::TaxSaving.new(
      fiscal_year: @fiscal_year,
      simulation: TaxSavingSimulator.new(@fiscal_year).calculate
    )
  end

  private

  # Last year's return while its 確定申告 is open (January–March), for its own
  # dashboard and this year's.
  def open_filing_year
    filing_year = FiscalYear.find_by(year: FiscalYear.current_year - 1)
    return unless filing_year&.open_filing_deadlines&.any?

    filing_year if @fiscal_year.year.in?([ filing_year.year, filing_year.year + 1 ])
  end

  # Until this year has a record, the dashboard the home page lands on offers to create it.
  def start_current_year?
    !FiscalYear.exists?(year: FiscalYear.current_year) && @fiscal_year == FiscalYear.home
  end

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:id])
  end

  def fiscal_year_params
    params.expect(fiscal_year: [ :year, :filing_type ])
  end
end
