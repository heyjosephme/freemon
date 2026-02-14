# frozen_string_literal: true

class Views::Expenses::New < Views::Base
  def initialize(fiscal_year:, expense:)
    @fiscal_year = fiscal_year
    @expense = expense
  end

  def view_template
    render PageHeader.new(title: "経費の追加", back_path: fiscal_year_expenses_path(@fiscal_year))
    render Views::Expenses::Form.new(fiscal_year: @fiscal_year, expense: @expense)
  end
end
