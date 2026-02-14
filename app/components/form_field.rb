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
      label(for: @name, class: "block text-sm font-medium text-gray-700 mb-1") do
        plain @label
        span(class: "text-red-500 ml-0.5") { "*" } if @required
      end

      if @type == "select" && @options
        render_select
      elsif @type == "checkbox"
        render_checkbox
      else
        render_input
      end

      if @hint && @errors.empty?
        p(class: "mt-1 text-sm text-gray-500") { @hint }
      end

      @errors.each do |error|
        p(class: "mt-1 text-sm text-red-600") { error }
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
      class: [
        "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6",
        @errors.any? ? "ring-red-300" : "ring-gray-300"
      ].join(" "),
      **@input_attrs
    )
  end

  def render_select
    select(
      name: @name,
      id: @name,
      class: "block w-full rounded-md border-0 py-1.5 px-3 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6"
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
          class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600", **@input_attrs)
      else
        input(type: "checkbox", name: @name, id: @name, value: "1",
          class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600", **@input_attrs)
      end
      # Hidden field so unchecked sends "0"
      input(type: "hidden", name: @name, value: "0")
      label(for: @name, class: "ml-2 text-sm text-gray-700") { @label }
    end
  end
end
