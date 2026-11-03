# frozen_string_literal: true

# Entry forms opened from a fiscal year's dashboard carry return_to=dashboard,
# so saving or cancelling goes back to the dashboard instead of the list.
module ReturnsToDashboard
  extend ActiveSupport::Concern

  private

  # Whitelisted, so the param can't redirect anywhere else.
  def return_to = params[:return_to].presence_in(%w[dashboard])

  def dashboard_or(list_path) = return_to ? fiscal_year_path(@fiscal_year) : list_path
end
