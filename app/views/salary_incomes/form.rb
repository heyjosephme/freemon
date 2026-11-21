# frozen_string_literal: true

class Views::SalaryIncomes::Form < Views::Base
  def initialize(fiscal_year:, salary_income:)
    @fiscal_year = fiscal_year
    @salary_income = salary_income
  end

  def view_template
    url = @salary_income.persisted? ? fiscal_year_salary_income_path(@fiscal_year) : fiscal_year_salary_income_path(@fiscal_year)
    method = @salary_income.persisted? ? :patch : :post

    form_with(model: @salary_income, url: url, method: method, class: "max-w-2xl space-y-6") do |f|
      render Card.new(title: "源泉徴収票の情報") do
        p(class: "text-sm text-muted mb-4") { "勤務先の源泉徴収票に記載されている金額を入力してください。" }

        field(:gross_salary, f, "支払金額 (Gross Salary)", hint: "源泉徴収票の「支払金額」欄")
        field(:tax_withheld, f, "源泉徴収税額 (Tax Withheld)", hint: "源泉徴収票の「源泉徴収税額」欄")
        field(:social_insurance, f, "社会保険料 (Social Insurance)", hint: "源泉徴収票の「社会保険料等の金額」欄")

        div(class: "flex gap-3 pt-4") do
          f.submit(@salary_income.persisted? ? "更新" : "登録",
            class: Button.classes)
          a(href: fiscal_year_path(@fiscal_year),
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end
  end

  private

  def field(attr, f, label, hint: nil)
    div(class: "mb-4") do
      f.label attr, label, class: LABEL
      f.number_field attr, min: 0, class: input_classes, placeholder: "¥"
      if hint
        p(class: "mt-1 text-sm text-muted") { hint }
      end
      @salary_income.errors[attr].each do |error|
        p(class: "mt-1 text-sm text-negative") { error }
      end
    end
  end

  def input_classes
    "block w-full #{INPUT}"
  end
end
