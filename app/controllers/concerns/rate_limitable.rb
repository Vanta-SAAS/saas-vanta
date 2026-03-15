module RateLimitable
  extend ActiveSupport::Concern

  class_methods do
    # Login, sign up, reset password: 5 req/min per IP
    def rate_limit_authentication(**options)
      rate_limit to: 5, within: 1.minute,
                 by: -> { request.remote_ip },
                 with: -> { render_rate_limit_response("Demasiados intentos. Intenta de nuevo más tarde.") },
                 **options
    end

    # General use: 120 req/min per user
    def rate_limit_general(**options)
      rate_limit to: 120, within: 1.minute,
                 by: -> { Current.user&.id || request.remote_ip },
                 with: -> { render_rate_limit_response("Demasiadas solicitudes. Intenta de nuevo más tarde.") },
                 **options
    end

    # Sensitive actions: 10 req/min per user
    def rate_limit_sensitive(**options)
      rate_limit to: 10, within: 1.minute,
                 by: -> { Current.user&.id || request.remote_ip },
                 with: -> { render_rate_limit_response("Has excedido el límite de solicitudes. Intenta de nuevo más tarde.") },
                 **options
    end
  end

  private

  def render_rate_limit_response(message)
    respond_to do |format|
      format.html { redirect_back(fallback_location: root_path, alert: message) }
      format.turbo_stream { redirect_back(fallback_location: root_path, alert: message) }
      format.json { render json: { error: message }, status: :too_many_requests }
    end
  end
end
