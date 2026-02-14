# frozen_string_literal: true

class Components::MoneyDisplay < Components::Base
  def initialize(amount:, size: :md)
    @amount = amount
    @size = size
  end

  def view_template
    classes = [
      size_classes,
      @amount.negative? ? "text-red-600" : "text-gray-900"
    ].join(" ")

    span(class: classes) { formatted_amount }
  end

  private

  def formatted_amount
    abs = ActiveSupport::NumberHelper.number_to_delimited(@amount.abs)
    if @amount.negative?
      "-¥#{abs}"
    else
      "¥#{abs}"
    end
  end

  def size_classes
    case @size
    when :sm then "text-sm"
    when :md then "text-base"
    when :lg then "text-xl font-bold"
    end
  end
end
