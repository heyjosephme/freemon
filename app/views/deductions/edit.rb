# frozen_string_literal: true

class Views::Deductions::Edit < Views::Base
  def initialize(fiscal_year:, deduction:)
    @fiscal_year = fiscal_year
    @deduction = deduction
  end

  def view_template
    render PageHeader.new(title: "控除の編集", back_path: fiscal_year_deductions_path(@fiscal_year))
    render Views::Deductions::Form.new(fiscal_year: @fiscal_year, deduction: @deduction)
  end
end
