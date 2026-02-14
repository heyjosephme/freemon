# frozen_string_literal: true

class AccountsController < ApplicationController
  before_action :set_account, only: [ :edit, :update ]

  def index
    @accounts = Account.ordered
    render Views::Accounts::Index.new(accounts: @accounts)
  end

  def new
    @account = Account.new
    render Views::Accounts::New.new(account: @account)
  end

  def create
    @account = Account.new(account_params)
    if @account.save
      redirect_to accounts_path, notice: "勘定科目を作成しました。"
    else
      render Views::Accounts::New.new(account: @account), status: :unprocessable_entity
    end
  end

  def edit
    render Views::Accounts::Edit.new(account: @account)
  end

  def update
    if @account.update(account_params)
      redirect_to accounts_path, notice: "勘定科目を更新しました。"
    else
      render Views::Accounts::Edit.new(account: @account), status: :unprocessable_entity
    end
  end

  private

  def set_account
    @account = Account.find(params[:id])
  end

  def account_params
    params.expect(account: [ :code, :name, :name_en, :account_type ])
  end
end
