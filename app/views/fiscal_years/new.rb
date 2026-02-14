# frozen_string_literal: true

class Views::FiscalYears::New < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "新規 確定申告年度", back_path: fiscal_years_path)
    render Views::FiscalYears::Form.new(fiscal_year: @fiscal_year)
  end
end
