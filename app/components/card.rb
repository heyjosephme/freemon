# frozen_string_literal: true

class Components::Card < Components::Base
  def initialize(title: nil)
    @title = title
  end

  def view_template(&block)
    div(class: "bg-white rounded-lg shadow-sm border border-gray-200 p-6") do
      if @title
        h2(class: "text-lg font-semibold text-gray-900 mb-4") { @title }
      end
      yield
    end
  end
end
