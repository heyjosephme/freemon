# frozen_string_literal: true

class Components::SummaryRow < Components::Base
  def initialize(label:, value: nil, highlight: false, indent: false)
    @label = label
    @value = value
    @highlight = highlight
    @indent = indent
  end

  def view_template(&block)
    classes = [
      "flex justify-between items-center py-2",
      @highlight ? "font-bold border-t-2 border-ink pt-3 mt-2" : "border-b border-line",
      @indent ? "pl-4" : ""
    ].join(" ")

    div(class: classes) do
      span(class: "text-sm text-muted") { @label }
      if block
        yield
      elsif @value.is_a?(Integer)
        render MoneyDisplay.new(amount: @value)
      else
        span(class: "text-sm font-medium text-ink") { @value.to_s }
      end
    end
  end
end
