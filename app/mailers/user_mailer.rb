class UserMailer < ApplicationMailer
  def invitation_email
    @user = params[:user]
    @enterprise = params[:enterprise]
    @invitation_url = edit_invitation_url(@user.invitation_token)

    mail(to: @user.email_address, subject: "Bienvenido a #{@enterprise.comercial_name} - Configura tu cuenta")
  end

  def confirmation_email
    @user = params[:user]
    @enterprise = params[:enterprise]
    @confirmation_url = edit_invitation_url(@user.invitation_token)

    mail(to: @user.email_address, subject: "Confirma tu cuenta - VANTA")
  end
end
