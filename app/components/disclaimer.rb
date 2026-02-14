# frozen_string_literal: true

class Components::Disclaimer < Components::Base
  def view_template
    div(class: "bg-yellow-50 border border-yellow-200 rounded-md p-4 mb-6") do
      p(class: "text-sm text-yellow-800") do
        strong { "注意: " }
        plain "これは税務シミュレーションツールです。参考用としてご利用ください。正式な申告には税理士にご相談ください。"
      end
    end
  end
end
