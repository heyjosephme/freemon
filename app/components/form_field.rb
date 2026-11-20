# frozen_string_literal: true

class Components::FormField < Components::Base
  def initialize(label:, name:, type: "text", value: nil, errors: [], hint: nil, required: false, options: nil, **input_attrs)
    @label = label
    @name = name
    @type = type
    @value = value
    @errors = Array(errors)
    @hint = hint
    @required = required
    @options = options
    @input_attrs = input_attrs
  end

  def view_template
    div(class: "mb-4") do
      label(for: @name, class: LABEL) do
        plain @label
        span(class: "text-negative ml-0.5") { "*" } if @required
      end

      if @type == "select" && @options
        render_select
      elsif @type == "checkbox"
        render_checkbox
      else
        render_input
      end

      if @hint && @errors.empty?
        p(class: "mt-1 text-sm text-muted") { @hint }
      end

      @errors.each do |error|
        p(class: "mt-1 text-sm text-negative") { error }
      end
    end
  end

  private

  def render_input
    input(
      type: @type,
      name: @name,
      id: @name,
      value: @value,
      class: "block w-full #{INPUT} #{"ring-negative" if @errors.any?}",
      **@input_attrs
    )
  end

  def render_select
    select(
      name: @name,
      id: @name,
      class: "block w-full #{INPUT}"
    ) do
      @options.each do |label_text, option_value|
        if option_value.to_s == @value.to_s
          option(value: option_value, selected: true) { label_text }
        else
          option(value: option_value) { label_text }
        end
      end
    end
  end

  def render_checkbox
    div(class: "flex items-center") do
      if @value
        input(type: "checkbox", name: @name, id: @name, value: "1", checked: true,
          class: CHECKBOX, **@input_attrs)
      else
        input(type: "checkbox", name: @name, id: @name, value: "1",
          class: CHECKBOX, **@input_attrs)
      end
      # Hidden field so unchecked sends "0"
      input(type: "hidden", name: @name, value: "0")
      label(for: @name, class: "ml-2 text-sm text-ink") { @label }
    end
  end
end
