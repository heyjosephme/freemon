# frozen_string_literal: true

class Components::Alert < Components::Base
  STYLES = {
    info: "bg-blue-50 text-blue-800 border-blue-200",
    success: "bg-green-50 text-green-800 border-green-200",
    warning: "bg-yellow-50 text-yellow-800 border-yellow-200",
    error: "bg-red-50 text-red-800 border-red-200"
  }.freeze

  def initialize(message:, type: :info)
    @message = message
    @type = type
  end

  def view_template
    div(class: "rounded-md border p-4 mb-4 #{STYLES[@type]}", data: { controller: "flash" }) do
      div(class: "flex justify-between items-center") do
        p(class: "text-sm") { @message }
        button(class: "text-current opacity-50 hover:opacity-100", data: { action: "flash#dismiss" }) { "✕" }
      end
    end
  end
end
