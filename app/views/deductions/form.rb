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
          f.label :deduction_type, "控除の種類 (Deduction Type)", class: LABEL
          f.select :deduction_type, Deduction::DEDUCTION_TYPE_LABELS.map { |k, v| [ v, k ] }, {}, class: input_classes
          @deduction.errors[:deduction_type].each do |error|
            p(class: "mt-1 text-sm text-negative") { error }
          end
        end

        div(class: "mb-4") do
          f.label :amount, "金額 (Amount)", class: LABEL
          f.number_field :amount, min: 1, class: input_classes, placeholder: "¥"
          @deduction.errors[:amount].each do |error|
            p(class: "mt-1 text-sm text-negative") { error }
          end
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@deduction.persisted? ? "更新" : "登録",
            class: Button.classes)
          a(href: fiscal_year_deductions_path(@fiscal_year),
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end
  end

  private

  def input_classes
    "block w-full #{INPUT}"
  end
end
