# frozen_string_literal: true

class Views::Revenues::Form < Views::Base
  def initialize(fiscal_year:, revenue:)
    @fiscal_year = fiscal_year
    @revenue = revenue
  end

  def view_template
    url = @revenue.persisted? ? fiscal_year_revenue_path(@fiscal_year, @revenue) : fiscal_year_revenues_path(@fiscal_year)

    form_with(model: @revenue, url: url, class: "space-y-6") do |f|
      render Card.new do
        field(f, :client_name, "取引先名 (Client Name)", type: :text_field)
        field(f, :amount, "金額 (税込) (Amount, tax included)", type: :number_field, min: 1, placeholder: "¥")
        field(f, :date, "日付 (Date)", type: :date_field)

        div(class: "mb-4") do
          f.label :invoices, "請求書・証憑 (Invoices/Documents)", class: "block text-sm font-medium text-gray-700 mb-1"
          f.file_field :invoices, multiple: true, accept: ".pdf,.png,.jpg,.jpeg",
            class: "block w-full text-sm text-gray-500 file:mr-4 file:py-2 file:px-4 file:rounded-md file:border-0 file:text-sm file:font-medium file:bg-indigo-50 file:text-indigo-700 hover:file:bg-indigo-100"
          p(class: "mt-1 text-sm text-gray-500") { "PDF, PNG, JPG (複数選択可)" }
        end

        if @revenue.persisted? && @revenue.invoices.attached?
          div(class: "mb-4") do
            p(class: "text-sm font-medium text-gray-700 mb-2") { "添付済みファイル:" }
            @revenue.invoices.each do |invoice|
              div(class: "flex items-center gap-2 text-sm text-gray-600 mb-1") do
                span { invoice.filename.to_s }
                span(class: "text-gray-400") { "(#{helpers.number_to_human_size(invoice.byte_size)})" }
              end
            end
          end
        end

        div(class: "flex gap-3 pt-4") do
          f.submit(@revenue.persisted? ? "更新" : "登録",
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer")
          a(href: fiscal_year_revenues_path(@fiscal_year),
            class: "inline-flex items-center px-4 py-2 rounded-md text-sm font-medium text-gray-700 bg-white border border-gray-300 hover:bg-gray-50") { "キャンセル" }
        end
      end
    end
  end

  private

  def field(f, attr, label, type:, **opts)
    div(class: "mb-4") do
      f.label attr, label, class: "block text-sm font-medium text-gray-700 mb-1"
      f.send(type, attr, class: input_classes, **opts)
      @revenue.errors[attr].each do |error|
        p(class: "mt-1 text-sm text-red-600") { error }
      end
    end
  end

  def input_classes
    "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
  end
end
