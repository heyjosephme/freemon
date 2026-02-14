# frozen_string_literal: true

class Views::Revenues::Edit < Views::Base
  def initialize(fiscal_year:, revenue:)
    @fiscal_year = fiscal_year
    @revenue = revenue
  end

  def view_template
    render PageHeader.new(title: "売上の編集", back_path: fiscal_year_revenues_path(@fiscal_year))
    render Views::Revenues::Form.new(fiscal_year: @fiscal_year, revenue: @revenue)
  end
end
