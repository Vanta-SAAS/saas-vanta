class SessionsController < ApplicationController
  layout "auth", only: %i[ new create ]
  allow_unauthenticated_access only: %i[ new create ]
  skip_enterprise_selection only: %i[ destroy ]
  before_action :redirect_if_authenticated, only: %i[ new create ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to login_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      if user.pending?
        redirect_to login_path, alert: "Tu cuenta aun no ha sido confirmada. Revisa tu correo electronico."
        return
      end

      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to login_path, alert: "Usuario o contraseña incorrectos"
    end
  end

  def destroy
    session.delete(:enterprise_id)
    terminate_session
    redirect_to login_path, status: :see_other
  end

  private

  def after_authentication_url
    user = Current.user

    if user.super_admin?
      admin_dashboard_path
    elsif user.standard?
      if user.enterprises.count > 1
        enterprises_path
      elsif user.enterprises.count == 1
        enterprise = user.enterprises.first
        session[:enterprise_id] = enterprise.id
        Current.session.update!(enterprise_id: enterprise.id)
        session.delete(:return_to_after_authenticating) || root_path
      else
        session.delete(:return_to_after_authenticating) || root_path
      end
    else
      super
    end
  end
end
