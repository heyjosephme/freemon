# frozen_string_literal: true

class Views::RecurringExpenses::Edit < Views::Base
  def initialize(recurring_expense:)
    @recurring_expense = recurring_expense
  end

  def view_template
    render PageHeader.new(title: "定期経費の編集", back_path: recurring_expenses_path)
    render Views::RecurringExpenses::Form.new(recurring_expense: @recurring_expense)
  end
end
