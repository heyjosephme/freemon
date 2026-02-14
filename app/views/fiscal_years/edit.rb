# frozen_string_literal: true

class Views::FiscalYears::Edit < Views::Base
  def initialize(fiscal_year:)
    @fiscal_year = fiscal_year
  end

  def view_template
    render PageHeader.new(title: "#{@fiscal_year.year}年 設定変更", back_path: fiscal_year_path(@fiscal_year))
    render Views::FiscalYears::Form.new(fiscal_year: @fiscal_year)
  end
end
