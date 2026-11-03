# frozen_string_literal: true

class Views::Expenses::Edit < Views::Base
  def initialize(fiscal_year:, expense:, back_path:, return_to: nil)
    @fiscal_year = fiscal_year
    @expense = expense
    @back_path = back_path
    @return_to = return_to
  end

  def view_template
    render PageHeader.new(title: "経費の編集", back_path: @back_path)
    render Views::Expenses::Form.new(fiscal_year: @fiscal_year, expense: @expense, back_path: @back_path, return_to: @return_to)
  end
end
