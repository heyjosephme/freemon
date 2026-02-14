# frozen_string_literal: true

class Views::Accounts::New < Views::Base
  def initialize(account:)
    @account = account
  end

  def view_template
    render PageHeader.new(title: "勘定科目の追加", back_path: accounts_path)
    render Views::Accounts::Form.new(account: @account)
  end
end
