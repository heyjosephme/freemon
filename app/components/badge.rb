# frozen_string_literal: true

class Components::Badge < Components::Base
  COLORS = {
    green: "bg-green-100 text-green-800",
    red: "bg-red-100 text-red-800",
    blue: "bg-blue-100 text-blue-800",
    gray: "bg-gray-100 text-gray-800",
    yellow: "bg-yellow-100 text-yellow-800",
    indigo: "bg-indigo-100 text-indigo-800"
  }.freeze

  def initialize(text:, color: :gray)
    @text = text
    @color = color
  end

  def view_template
    span(class: "inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium #{COLORS[@color]}") do
      @text
    end
  end
end
