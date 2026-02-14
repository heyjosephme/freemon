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

ActiveRecord::Schema[8.1].define(version: 2026_02_14_073344) do
  create_table "accounts", force: :cascade do |t|
    t.integer "account_type", null: false
    t.string "code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.string "name_en"
    t.boolean "system_default", default: false, null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_accounts_on_code", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "journal_entries", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.date "date", null: false
    t.string "description", null: false
    t.integer "fiscal_year_id", null: false
    t.integer "source_id"
    t.string "source_type"
    t.datetime "updated_at", null: false
    t.index ["fiscal_year_id", "date"], name: "index_journal_entries_on_fiscal_year_id_and_date"
    t.index ["fiscal_year_id"], name: "index_journal_entries_on_fiscal_year_id"
    t.index ["source_type", "source_id"], name: "index_journal_entries_on_source_type_and_source_id", unique: true, where: "source_type IS NOT NULL"
  end

  create_table "journal_entry_lines", force: :cascade do |t|
    t.integer "account_id", null: false
    t.integer "amount", null: false
    t.datetime "created_at", null: false
    t.integer "journal_entry_id", null: false
    t.integer "side", null: false
    t.datetime "updated_at", null: false
    t.index ["account_id"], name: "index_journal_entry_lines_on_account_id"
    t.index ["journal_entry_id"], name: "index_journal_entry_lines_on_journal_entry_id"
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

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "deductions", "fiscal_years"
  add_foreign_key "expenses", "fiscal_years"
  add_foreign_key "journal_entries", "fiscal_years"
  add_foreign_key "journal_entry_lines", "accounts"
  add_foreign_key "journal_entry_lines", "journal_entries"
  add_foreign_key "revenues", "fiscal_years"
  add_foreign_key "salary_incomes", "fiscal_years"
end
