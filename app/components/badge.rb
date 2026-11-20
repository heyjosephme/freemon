# frozen_string_literal: true

class Components::Badge < Components::Base
  # Keyed by the old palette names; each maps to a status role.
  COLORS = {
    green: "bg-positive-soft text-positive",
    red: "bg-negative-soft text-negative",
    blue: "bg-info-soft text-info",
    gray: "bg-sunken text-muted",
    yellow: "bg-warning-soft text-warning",
    indigo: "bg-primary-soft text-primary"
  }.freeze

  def initialize(text:, color: :gray)
    @text = text
    @color = color
  end

  def view_template
    span(class: "inline-flex items-center whitespace-nowrap px-2.5 py-0.5 rounded-full text-xs font-medium #{COLORS[@color]}") do
      @text
    end
  end
end
