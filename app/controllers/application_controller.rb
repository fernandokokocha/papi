class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # One bucket for the whole app, not one per controller: scope: defaults to
  # controller_path, which would hand every subclass its own 60. Keyed by user
  # where there is one, so an office behind a single NAT is not one client.
  rate_limit to: 60, within: 1.minute, scope: :global,
    by: -> { Current.user&.id || request.remote_ip }

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back_or_to(projects_path)
  end

  def pundit_user
    Current.user
  end
end
