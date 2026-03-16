class ApplicationController < ActionController::Base
  include Authentication
  include Pundit::Authorization
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  layout -> { @use_tailwind ? "tailwind" : "application" }

  before_action :set_design_variant

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  def set_design_variant
    if params[:design] == "v2"
      @use_tailwind = true
      request.variant = :v2
    end
  end

  def user_not_authorized
    flash[:alert] = "You are not authorized to perform this action."
    redirect_back_or_to(root_path)
  end

  def pundit_user
    Current.user
  end
end
