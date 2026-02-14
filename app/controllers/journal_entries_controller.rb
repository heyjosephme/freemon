# frozen_string_literal: true

class JournalEntriesController < ApplicationController
  before_action :set_fiscal_year
  before_action :set_journal_entry, only: [ :edit, :update, :destroy ]

  def index
    @journal_entries = @fiscal_year.journal_entries.includes(lines: :account).chronological
    render Views::JournalEntries::Index.new(fiscal_year: @fiscal_year, journal_entries: @journal_entries)
  end

  def new
    @journal_entry = @fiscal_year.journal_entries.build(date: Date.new(@fiscal_year.year, 1, 1))
    2.times { @journal_entry.lines.build }
    render Views::JournalEntries::New.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry)
  end

  def create
    @journal_entry = @fiscal_year.journal_entries.build(journal_entry_params)
    if @journal_entry.save
      redirect_to fiscal_year_journal_entries_path(@fiscal_year), notice: "仕訳を登録しました。"
    else
      render Views::JournalEntries::New.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry), status: :unprocessable_entity
    end
  end

  def edit
    unless @journal_entry.manual?
      redirect_to fiscal_year_journal_entries_path(@fiscal_year), alert: "自動生成された仕訳は編集できません。元の売上・経費を編集してください。"
      return
    end
    render Views::JournalEntries::Edit.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry)
  end

  def update
    unless @journal_entry.manual?
      redirect_to fiscal_year_journal_entries_path(@fiscal_year), alert: "自動生成された仕訳は編集できません。"
      return
    end

    if @journal_entry.update(journal_entry_params)
      redirect_to fiscal_year_journal_entries_path(@fiscal_year), notice: "仕訳を更新しました。"
    else
      render Views::JournalEntries::Edit.new(fiscal_year: @fiscal_year, journal_entry: @journal_entry), status: :unprocessable_entity
    end
  end

  def destroy
    unless @journal_entry.manual?
      redirect_to fiscal_year_journal_entries_path(@fiscal_year), alert: "自動生成された仕訳は削除できません。元の売上・経費を削除してください。"
      return
    end

    @journal_entry.destroy
    redirect_to fiscal_year_journal_entries_path(@fiscal_year), notice: "仕訳を削除しました。"
  end

  private

  def set_fiscal_year
    @fiscal_year = FiscalYear.find(params[:fiscal_year_id])
  end

  def set_journal_entry
    @journal_entry = @fiscal_year.journal_entries.find(params[:id])
  end

  def journal_entry_params
    params.expect(journal_entry: [ :date, :description, lines_attributes: [ [ :id, :account_id, :side, :amount, :_destroy ] ] ])
  end
end
