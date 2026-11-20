# frozen_string_literal: true

# Horizontal proportion bars (HTML, not SVG). Each slice responds to
# #label, #amount and #pct. Bar widths use an inline style so Tailwind's
# purge never strips the dynamic percentage.
class Components::Charts::ProportionBars < Components::Base
  def initialize(slices:, color: "bg-primary")
    @slices = slices
    @color = color
  end

  def view_template
    if @slices.empty?
      p(class: "text-sm text-subtle py-4") { "データがありません。" }
      return
    end

    div(class: "space-y-3") do
      @slices.each do |slice|
        div do
          div(class: "flex justify-between items-baseline text-sm mb-1") do
            span(class: "text-ink truncate pr-2") { slice.label }
            span(class: "text-muted whitespace-nowrap") do
              render Components::MoneyDisplay.new(amount: slice.amount, size: :sm)
              plain " · #{slice.pct}%"
            end
          end
          div(class: "w-full bg-sunken rounded-full h-2") do
            div(class: "#{@color} h-2 rounded-full", style: "width: #{slice.pct}%")
          end
        end
      end
    end
  end
end
