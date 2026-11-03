class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :navbar_fiscal_years

  private

  def navbar_fiscal_years
    @navbar_fiscal_years ||= FiscalYear.order(year: :desc).to_a
  end
end
