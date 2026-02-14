# frozen_string_literal: true

class Views::Deductions::Form < Views::Base
  def initialize(fiscal_year:, deduction:)
    @fiscal_year = fiscal_year
    @deduction = deduction
  end

  def view_template
    url = @deduction.persisted? ? fiscal_year_deduction_path(@fiscal_year, @deduction) : fiscal_year_deductions_path(@fiscal_year)

    form_with(model: @deduction, url: url, class: "space-y-6") do |f|
      render Card.new do
        div(class: "mb-4") do
          f.label :deduction_type, "控除の種類 (Deduction Type)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.select :deduction_type, Deduction::DEDUCTION_TYPE_LABELS.map { |k, v| [ v, k ] }, {}, class: input_classes
          @deduction.errors[:deduction_type].each do |error|
            p(class: "mt-1 text-sm text-red-600") { error }
          end
        end

        div(class: "mb-4") do
          f.label :amount, "金額 (Amount)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.number_field :amount, min: 1, class: input_classes, placeholder: "¥"
          @deduction.errors[:amount].each do |error|
            p(class: "mt-1 text-sm text-red-600") { error }
          end
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@deduction.persisted? ? "更新" : "登録",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: fiscal_year_deductions_path(@fiscal_year),
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
