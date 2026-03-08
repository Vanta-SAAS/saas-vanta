class ApplicationController < ActionController::Base
  include Authentication
  include Authorization
  include ModuleAccess
  include Pagy::Backend

  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  # Changes to the importmap will invalidate the etag for HTML responses
  stale_when_importmap_changes

  helper_method :current_enterprise

  # Handle authorization errors
  rescue_from Authorization::NotAuthorizedError, with: :user_not_authorized

  private

  def current_enterprise
    @current_enterprise ||= Current.user&.enterprises&.find_by(id: session[:enterprise_id])
  end

  def user_not_authorized(exception)
    flash[:alert] = exception.message
    redirect_back(fallback_location: root_path)
  end
end
