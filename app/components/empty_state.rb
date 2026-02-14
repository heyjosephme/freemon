# frozen_string_literal: true

class Components::EmptyState < Components::Base
  def initialize(message:, action_text: nil, action_path: nil)
    @message = message
    @action_text = action_text
    @action_path = action_path
  end

  def view_template
    div(class: "text-center py-12") do
      p(class: "text-gray-500 mb-4") { @message }
      if @action_text && @action_path
        render Button.new(href: @action_path) { @action_text }
      end
    end
  end
end
