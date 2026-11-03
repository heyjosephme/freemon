# frozen_string_literal: true

class Views::Revenues::Edit < Views::Base
  def initialize(fiscal_year:, revenue:, back_path:, return_to: nil)
    @fiscal_year = fiscal_year
    @revenue = revenue
    @back_path = back_path
    @return_to = return_to
  end

  def view_template
    render PageHeader.new(title: "売上の編集", back_path: @back_path)
    render Views::Revenues::Form.new(fiscal_year: @fiscal_year, revenue: @revenue, back_path: @back_path, return_to: @return_to)
  end
end
