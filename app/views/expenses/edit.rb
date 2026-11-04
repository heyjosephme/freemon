# frozen_string_literal: true

class Views::Expenses::Edit < Views::Base
  def initialize(fiscal_year:, expense:, back_path:, return_to: nil)
    @fiscal_year = fiscal_year
    @expense = expense
    @back_path = back_path
    @return_to = return_to
  end

  def view_template
    render PageHeader.new(title: "経費の編集", back_path: @back_path) do
      # Bills like this one can repeat as a 定期経費, copied from here.
      if @expense.ordinary? && @expense.recurring_expense_id.nil?
        render Button.new(href: new_recurring_expense_path(from_expense: @expense.id), variant: :secondary, size: :sm) { "定期経費にする" }
      end
    end
    render Views::Expenses::Form.new(fiscal_year: @fiscal_year, expense: @expense, back_path: @back_path, return_to: @return_to)
  end
end
