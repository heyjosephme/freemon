# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_02_14_061540) do
  create_table "deductions", force: :cascade do |t|
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.integer "deduction_type", null: false
    t.integer "fiscal_year_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_year_id"], name: "index_deductions_on_fiscal_year_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "amount", null: false
    t.integer "business_ratio", default: 100, null: false
    t.integer "category", default: 6, null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.integer "fiscal_year_id", null: false
    t.boolean "invoice_eligible", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_year_id"], name: "index_expenses_on_fiscal_year_id"
  end

  create_table "fiscal_years", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "filing_type", default: 0, null: false
    t.datetime "updated_at", null: false
    t.integer "year", null: false
    t.index ["year"], name: "index_fiscal_years_on_year", unique: true
  end

  create_table "revenues", force: :cascade do |t|
    t.integer "amount", null: false
    t.string "client_name", null: false
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.integer "fiscal_year_id", null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_year_id"], name: "index_revenues_on_fiscal_year_id"
  end

  create_table "salary_incomes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "fiscal_year_id", null: false
    t.integer "gross_salary", null: false
    t.integer "social_insurance", null: false
    t.integer "tax_withheld", null: false
    t.datetime "updated_at", null: false
    t.index ["fiscal_year_id"], name: "index_salary_incomes_on_fiscal_year_id", unique: true
  end

  add_foreign_key "deductions", "fiscal_years"
  add_foreign_key "expenses", "fiscal_years"
  add_foreign_key "revenues", "fiscal_years"
  add_foreign_key "salary_incomes", "fiscal_years"
end
