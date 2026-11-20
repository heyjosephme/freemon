# frozen_string_literal: true

class Components::Button < Components::Base
  BASE = "inline-flex items-center justify-center rounded-md font-medium whitespace-nowrap transition-colors cursor-pointer"

  VARIANTS = {
    primary: "bg-primary text-on-primary hover:bg-primary-hover",
    secondary: "bg-surface text-ink ring-1 ring-inset ring-line-strong hover:bg-sunken",
    danger: "bg-negative text-on-primary hover:opacity-90",
    ghost: "text-primary hover:text-primary-hover"
  }.freeze

  SIZES = {
    sm: "px-3 py-1.5 text-sm",
    md: "px-4 py-2 text-sm",
    lg: "px-6 py-3 text-base"
  }.freeze

  # The same look for buttons that Rails helpers render (f.submit, button_to).
  def self.classes(variant: :primary, size: :md) = [ BASE, VARIANTS.fetch(variant), SIZES.fetch(size) ].join(" ")

  def initialize(href: nil, variant: :primary, size: :md, **attrs)
    @href = href
    @variant = variant
    @size = size
    @attrs = attrs
  end

  def view_template(&block)
    classes = self.class.classes(variant: @variant, size: @size)

    if @href
      a(href: @href, class: classes, **@attrs) { yield }
    else
      button(class: classes, **@attrs) { yield }
    end
  end
end
