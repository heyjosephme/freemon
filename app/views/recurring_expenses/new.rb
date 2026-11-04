# frozen_string_literal: true

class Views::RecurringExpenses::New < Views::Base
  def initialize(recurring_expense:)
    @recurring_expense = recurring_expense
  end

  def view_template
    render PageHeader.new(title: "定期経費の追加", back_path: recurring_expenses_path)
    render Views::RecurringExpenses::Form.new(recurring_expense: @recurring_expense)
  end
end
