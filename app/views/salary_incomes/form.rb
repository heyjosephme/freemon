# frozen_string_literal: true

class Views::SalaryIncomes::Form < Views::Base
  def initialize(fiscal_year:, salary_income:)
    @fiscal_year = fiscal_year
    @salary_income = salary_income
  end

  def view_template
    url = @salary_income.persisted? ? fiscal_year_salary_income_path(@fiscal_year) : fiscal_year_salary_income_path(@fiscal_year)
    method = @salary_income.persisted? ? :patch : :post

    form_with(model: @salary_income, url: url, method: method, class: "space-y-6") do |f|
      render Card.new(title: "源泉徴収票の情報") do
        p(class: "text-sm text-gray-500 mb-4") { "勤務先の源泉徴収票に記載されている金額を入力してください。" }

        field(:gross_salary, f, "支払金額 (Gross Salary)", hint: "源泉徴収票の「支払金額」欄")
        field(:tax_withheld, f, "源泉徴収税額 (Tax Withheld)", hint: "源泉徴収票の「源泉徴収税額」欄")
        field(:social_insurance, f, "社会保険料 (Social Insurance)", hint: "源泉徴収票の「社会保険料等の金額」欄")

        div(class: "flex gap-3 pt-4") do
          f.submit(@salary_income.persisted? ? "更新" : "登録",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: fiscal_year_path(@fiscal_year),
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def field(attr, f, label, hint: nil)
    div(class: "mb-4") do
      f.label attr, label, class: "block text-sm font-medium text-gray-700 mb-1"
      f.number_field attr, min: 0, class: input_classes, placeholder: "¥"
      if hint
        p(class: "mt-1 text-sm text-gray-500") { hint }
      end
      @salary_income.errors[attr].each do |error|
        p(class: "mt-1 text-sm text-red-600") { error }
      end
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
