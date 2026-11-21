# frozen_string_literal: true

class Views::Revenues::Form < Views::Base
  def initialize(fiscal_year:, revenue:, back_path:, return_to: nil)
    @fiscal_year = fiscal_year
    @revenue = revenue
    @back_path = back_path
    @return_to = return_to
  end

  def view_template
    url = @revenue.persisted? ? fiscal_year_revenue_path(@fiscal_year, @revenue) : fiscal_year_revenues_path(@fiscal_year)

    form_with(model: @revenue, url: url, class: "max-w-2xl space-y-6") do |f|
      input(type: "hidden", name: "return_to", value: @return_to) if @return_to
      render Card.new do
        field(f, :client_name, "取引先名 (Client Name)", type: :text_field)
        field(f, :amount, "金額 (税込) (Amount, tax included)", type: :number_field, min: 1, placeholder: "¥")
        field(f, :date, "日付 (Date)", type: :date_field)

        div(class: "mb-4") do
          f.label :invoices, "請求書・証憑 (Invoices/Documents)", class: LABEL
          f.file_field :invoices, multiple: true, accept: ".pdf,.png,.jpg,.jpeg",
            class: "block w-full text-sm text-muted file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:cursor-pointer file:bg-primary-soft file:text-primary hover:file:bg-primary-line"
          p(class: "mt-1 text-sm text-muted") { "PDF, PNG, JPG (複数選択可)" }
        end

        render AttachedFiles.new(attachments: @revenue.invoices, field_name: "revenue[invoices][]")

        div(class: "flex gap-3 pt-4") do
          f.submit(@revenue.persisted? ? "更新" : "登録",
            class: Button.classes)
          a(href: @back_path,
            class: Button.classes(variant: :secondary)) { "キャンセル" }
        end
      end
    end
  end

  private

  def field(f, attr, label, type:, **opts)
    div(class: "mb-4") do
      f.label attr, label, class: LABEL
      f.send(type, attr, class: input_classes, **opts)
      @revenue.errors[attr].each do |error|
        p(class: "mt-1 text-sm text-negative") { error }
      end
    end
  end

  def input_classes
    "block w-full #{INPUT}"
  end
end
