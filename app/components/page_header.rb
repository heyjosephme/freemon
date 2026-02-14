# frozen_string_literal: true

class Components::PageHeader < Components::Base
  def initialize(title:, back_path: nil)
    @title = title
    @back_path = back_path
  end

  def view_template(&block)
    div(class: "mb-6") do
      if @back_path
        a(href: @back_path, class: "text-sm text-indigo-600 hover:text-indigo-800 mb-2 inline-block") { "← 戻る" }
      end
      div(class: "flex items-center justify-between") do
        h1(class: "text-2xl font-bold text-gray-900") { @title }
        div(class: "flex gap-2") { yield } if block
      end
    end
  end
end
