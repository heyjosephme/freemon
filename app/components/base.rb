# frozen_string_literal: true

class Components::Base < Phlex::HTML
  include Phlex::Rails::Helpers::Routes
  include Phlex::Rails::Helpers::FormWith
  include Phlex::Rails::Helpers::ButtonTo
  include Phlex::Rails::Helpers::LinkTo
  include Phlex::Rails::Helpers::ContentFor

  # <turbo-frame>, for parts of a page that load on their own (複製's inline row).
  register_element :turbo_frame

  # Class strings for controls that views build by hand (form_with fields, plain
  # links), so they match FormField and Button. Colours are roles from
  # app/assets/tailwind/application.css.
  INPUT = "rounded-md border-0 bg-surface py-1.5 px-3 text-sm text-ink ring-1 ring-inset ring-line-strong outline-none focus:ring-2 focus:ring-primary"
  LABEL = "block text-sm font-medium text-ink mb-1"
  LINK = "text-primary hover:text-primary-hover hover:underline underline-offset-4"
  CHECKBOX = "h-4 w-4 rounded border-line-strong accent-primary"

  if Rails.env.development?
    def before_template
      comment { "Before #{self.class.name}" }
      super
    end
  end
end
