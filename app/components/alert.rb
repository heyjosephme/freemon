# frozen_string_literal: true

class Components::Alert < Components::Base
  STYLES = {
    info: "bg-info-soft text-info border-info-line",
    success: "bg-positive-soft text-positive border-positive-line",
    warning: "bg-warning-soft text-warning border-warning-line",
    error: "bg-negative-soft text-negative border-negative-line"
  }.freeze

  def initialize(message:, type: :info)
    @message = message
    @type = type
  end

  def view_template
    div(class: "rounded-md border p-4 mb-4 #{STYLES[@type]}", data: { controller: "flash" }) do
      div(class: "flex justify-between items-center") do
        p(class: "text-sm") { @message }
        button(class: "text-current opacity-60 hover:opacity-100 cursor-pointer", aria_label: "閉じる", data: { action: "flash#dismiss" }) { "✕" }
      end
    end
  end
end
