# frozen_string_literal: true

class Components::PageHeader < Components::Base
  def initialize(title:, back_path: nil)
    @title = title
    @back_path = back_path
  end

  def view_template(&block)
    div(class: "mb-6") do
      if @back_path
        a(href: @back_path, class: "text-sm #{LINK} mb-2 inline-block") { "← 戻る" }
      end
      div(class: "flex items-end justify-between gap-4") do
        h1(class: "font-display text-3xl font-semibold tracking-wide text-ink") { @title }
        div(class: "flex gap-2") { yield } if block
      end
    end
  end
end
