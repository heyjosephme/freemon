# frozen_string_literal: true

class Components::Button < Components::Base
  VARIANTS = {
    primary: "bg-indigo-600 text-white hover:bg-indigo-700",
    secondary: "bg-white text-gray-700 border border-gray-300 hover:bg-gray-50",
    danger: "bg-red-600 text-white hover:bg-red-700",
    ghost: "text-indigo-600 hover:text-indigo-800"
  }.freeze

  def initialize(href: nil, variant: :primary, size: :md, **attrs)
    @href = href
    @variant = variant
    @size = size
    @attrs = attrs
  end

  def view_template(&block)
    classes = [
      "inline-flex items-center justify-center rounded-md font-medium transition-colors focus:outline-none focus:ring-2 focus:ring-indigo-500 focus:ring-offset-2",
      VARIANTS[@variant],
      size_classes
    ].join(" ")

    if @href
      a(href: @href, class: classes, **@attrs) { yield }
    else
      button(class: classes, **@attrs) { yield }
    end
  end

  private

  def size_classes
    case @size
    when :sm then "px-3 py-1.5 text-sm"
    when :md then "px-4 py-2 text-sm"
    when :lg then "px-6 py-3 text-base"
    end
  end
end
