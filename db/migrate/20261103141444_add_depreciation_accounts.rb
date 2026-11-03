# frozen_string_literal: true

# Accounts the asset journal entries post to. db/seeds.rb has them for new
# databases; this adds them to existing ones that already have a chart of
# accounts (an empty table is left for the seeds).
class AddDepreciationAccounts < ActiveRecord::Migration[8.1]
  ACCOUNTS = [
    { code: "150", name: "工具器具備品", name_en: "Tools & Equipment", account_type: 0 },
    { code: "151", name: "一括償却資産", name_en: "Lump-sum Depreciable Assets", account_type: 0 },
    { code: "152", name: "ソフトウェア", name_en: "Software", account_type: 0 },
    { code: "511", name: "減価償却費", name_en: "Depreciation", account_type: 4 }
  ].freeze

  class Account < ActiveRecord::Base
    self.table_name = "accounts"
  end

  def up
    return unless Account.exists?

    ACCOUNTS.each do |attributes|
      Account.create!(attributes.merge(system_default: true)) unless Account.exists?(code: attributes[:code])
    end
  end

  def down
    Account.where(code: ACCOUNTS.pluck(:code)).delete_all
  end
end
