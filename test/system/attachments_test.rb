# frozen_string_literal: true

require "application_system_test_case"

class AttachmentsTest < ApplicationSystemTestCase
  # These forms work without JavaScript, and rack_test submits them exactly as
  # rendered (hidden fields, checkboxes, file inputs), so no browser is needed.
  driven_by :rack_test

  setup do
    @fiscal_year = FiscalYear.create!(year: 2099, filing_type: :blue_65)
  end

  test "saving a revenue without choosing a file keeps its invoices" do
    revenue = create_revenue
    visit edit_fiscal_year_revenue_path(@fiscal_year, revenue)
    fill_in "取引先名 (Client Name)", with: "改名社"
    click_on "更新"

    assert_text "売上を更新しました。"
    assert_equal "改名社", revenue.reload.client_name
    assert_equal [ "first.pdf" ], filenames(revenue.invoices)
  end

  test "choosing a file adds it alongside a revenue's existing invoices" do
    revenue = create_revenue
    visit edit_fiscal_year_revenue_path(@fiscal_year, revenue)
    attach_file "請求書・証憑 (Invoices/Documents)", file_fixture("document.pdf")
    click_on "更新"

    assert_equal [ "document.pdf", "first.pdf" ], filenames(revenue.reload.invoices)
  end

  test "unchecking an attached invoice removes it" do
    revenue = create_revenue
    visit edit_fiscal_year_revenue_path(@fiscal_year, revenue)
    uncheck "first.pdf"
    click_on "更新"

    assert_empty revenue.reload.invoices
  end

  test "a failed revenue update re-renders the saved invoices" do
    revenue = create_revenue
    visit edit_fiscal_year_revenue_path(@fiscal_year, revenue)
    fill_in "金額 (税込) (Amount, tax included)", with: ""
    attach_file "請求書・証憑 (Invoices/Documents)", file_fixture("document.pdf")
    click_on "更新"

    assert_checked_field "first.pdf"
    assert_equal [ "first.pdf" ], filenames(revenue.reload.invoices)
  end

  test "saving an expense without choosing a file keeps its receipts" do
    expense = create_expense
    visit edit_fiscal_year_expense_path(@fiscal_year, expense)
    fill_in "内容 (Description)", with: "名称変更"
    click_on "更新"

    assert_equal "名称変更", expense.reload.description
    assert_equal [ "first.pdf" ], filenames(expense.receipts)
  end

  test "choosing a file adds it alongside an expense's existing receipts" do
    expense = create_expense
    visit edit_fiscal_year_expense_path(@fiscal_year, expense)
    attach_file "領収書・請求書 (Receipts/Invoices)", file_fixture("document.pdf")
    click_on "更新"

    assert_equal [ "document.pdf", "first.pdf" ], filenames(expense.reload.receipts)
  end

  test "unchecking an attached receipt removes it" do
    expense = create_expense
    visit edit_fiscal_year_expense_path(@fiscal_year, expense)
    uncheck "first.pdf"
    click_on "更新"

    assert_empty expense.reload.receipts
  end

  private

  def create_revenue
    @fiscal_year.revenues.create!(client_name: "テスト社", amount: 110_000, date: Date.new(2099, 6, 1),
                                  invoices: [ saved_pdf ])
  end

  def create_expense
    @fiscal_year.expenses.create!(description: "PC", amount: 110_000, category: :equipment, business_ratio: 100,
                                  date: Date.new(2099, 6, 1), receipts: [ saved_pdf ])
  end

  def saved_pdf
    { io: StringIO.new(file_fixture("document.pdf").binread), filename: "first.pdf", content_type: "application/pdf" }
  end

  def filenames(attachments)
    attachments.map { |attachment| attachment.filename.to_s }.sort
  end
end
