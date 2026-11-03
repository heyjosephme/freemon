# frozen_string_literal: true

require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup do
    @expense = FiscalYear.create!(year: 2099).expenses.create!(description: "コーヒー豆", amount: 1_200, category: :other,
                                                              date: Date.new(2099, 1, 1))
  end

  test "expenses default to in-person" do
    assert @expense.in_person?
    assert_equal "店頭・対面", @expense.purchase_channel_label
  end

  test "an in-person expense needs a receipt until one is attached; an online one never does" do
    assert @expense.receipt_missing?

    @expense.receipts.attach(io: StringIO.new("%PDF-1.4"), filename: "receipt.pdf", content_type: "application/pdf")
    assert_not @expense.receipt_missing?

    assert_not Expense.new(purchase_channel: :online).receipt_missing?
  end
end
