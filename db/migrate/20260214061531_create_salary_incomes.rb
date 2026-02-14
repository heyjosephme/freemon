class CreateSalaryIncomes < ActiveRecord::Migration[8.1]
  def change
    create_table :salary_incomes do |t|
      t.references :fiscal_year, null: false, foreign_key: true, index: { unique: true }
      t.integer :gross_salary, null: false
      t.integer :tax_withheld, null: false
      t.integer :social_insurance, null: false

      t.timestamps
    end
  end
end
