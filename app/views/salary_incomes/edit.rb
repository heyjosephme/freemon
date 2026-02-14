# frozen_string_literal: true

class Views::SalaryIncomes::Edit < Views::Base
  def initialize(fiscal_year:, salary_income:)
    @fiscal_year = fiscal_year
    @salary_income = salary_income
  end

  def view_template
    render PageHeader.new(title: "給与情報の編集", back_path: fiscal_year_path(@fiscal_year))
    render Views::SalaryIncomes::Form.new(fiscal_year: @fiscal_year, salary_income: @salary_income)
  end
end
