# frozen_string_literal: true

class Components::Card < Components::Base
  def initialize(title: nil)
    @title = title
  end

  def view_template(&block)
    div(class: "bg-surface rounded-lg border border-line p-6") do
      if @title
        h2(class: "text-base font-semibold text-ink mb-4") { @title }
      end
      yield
    end
  end
end
