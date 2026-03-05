class RegistrationsController < ApplicationController
  layout "auth"
  allow_unauthenticated_access
  before_action :redirect_if_authenticated, only: %i[ new create ]

  rate_limit to: 5, within: 3.minutes, only: :create, with: -> { redirect_to new_registration_path, alert: "Demasiados intentos. Intenta de nuevo mas tarde." }

  def new
  end

  def create
    result = Users::RegisterWithEnterprise.new(registration_params).call

    if result.valid?
      redirect_to pending_registration_path
    else
      @user_params = registration_params[:user] || {}
      @enterprise_params = registration_params[:enterprise] || {}
      flash.now[:alert] = result.errors.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  def pending
  end

  private

  def registration_params
    params.require(:registration).permit(
      user: [ :first_name, :first_last_name, :second_last_name, :phone_number, :email_address ],
      enterprise: [ :comercial_name ]
    )
  end
end
