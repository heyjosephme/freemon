# frozen_string_literal: true

# 接待交際費, the account the entertainment expense category posts to.
# db/seeds.rb has it for new databases; this adds it to existing ones that
# already have a chart of accounts (an empty table is left for the seeds).
class AddEntertainmentAccount < ActiveRecord::Migration[8.1]
  class Account < ActiveRecord::Base
    self.table_name = "accounts"
  end

  def up
    return unless Account.exists?
    return if Account.exists?(code: "512")

    Account.create!(code: "512", name: "接待交際費", name_en: "Entertainment", account_type: 4, system_default: true)
  end

  def down
    Account.where(code: "512").delete_all
  end
end
