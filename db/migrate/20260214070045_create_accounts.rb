class CreateAccounts < ActiveRecord::Migration[8.1]
  def change
    create_table :accounts do |t|
      t.string :code, null: false
      t.string :name, null: false
      t.string :name_en
      t.integer :account_type, null: false
      t.boolean :system_default, null: false, default: false

      t.timestamps
    end

    add_index :accounts, :code, unique: true
  end
end
