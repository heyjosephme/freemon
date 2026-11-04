# frozen_string_literal: true

# 複製's inline row: the new-revenue form filled in from another revenue, loaded
# into the empty turbo-frame under that revenue. Saving reloads the whole page
# (_top), so the new revenue shows up in the list; キャンセル or Esc empties the
# frame again.
class Views::Revenues::CopyRow < Views::Base
  INPUT = "rounded-md border-0 py-1.5 px-2 text-sm text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600"

  # The frame under each copyable revenue, which this row is rendered into.
  def self.frame_id(revenue) = "copy_revenue_#{revenue.id}"

  def initialize(fiscal_year:, revenue:, source:, return_to: nil)
    @fiscal_year = fiscal_year
    @revenue = revenue
    @source = source
    @return_to = return_to
  end

  def view_template
    turbo_frame(id: self.class.frame_id(@source), class: "block") do
      # The namespace keeps field ids apart when several rows are open at once.
      form_with(model: @revenue, url: fiscal_year_revenues_path(@fiscal_year), namespace: "copy_#{@source.id}",
                class: "my-1 flex flex-wrap items-center gap-2 rounded-md bg-indigo-50 px-2 py-2",
                data: { turbo_frame: "_top", controller: "inline-form", action: "keydown.esc->inline-form#cancel" }) do |f|
        input(type: "hidden", name: "return_to", value: @return_to) if @return_to
        f.label :date, "日付", class: "sr-only"
        f.date_field :date, required: true, class: "#{INPUT} w-36"
        f.label :client_name, "取引先", class: "sr-only"
        f.text_field :client_name, required: true, class: "#{INPUT} min-w-0 flex-1 basis-32"
        f.label :amount, "金額（税込）", class: "sr-only"
        # Focused, so checking the amount and pressing Enter is all it takes.
        f.number_field :amount, required: true, min: 1, autofocus: true, class: "#{INPUT} w-28 text-right"
        f.submit "登録", class: "inline-flex items-center px-3 py-1.5 rounded-md text-sm font-medium text-white bg-indigo-600 hover:bg-indigo-700 cursor-pointer"
        button(type: "button", data: { action: "inline-form#cancel" }, class: "text-xs text-gray-500 hover:text-gray-800 cursor-pointer") { "キャンセル" }
      end
    end
  end
end
