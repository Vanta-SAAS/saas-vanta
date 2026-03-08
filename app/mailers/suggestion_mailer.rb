class SuggestionMailer < ApplicationMailer
  def new_suggestion
    @suggestion = params[:suggestion]
    @user = @suggestion.user
    @enterprise = @suggestion.enterprise

    mail(
      to: "info@vanta.lat",
      subject: "Nueva sugerencia de #{@user.full_name} - #{@enterprise.comercial_name}"
    )
  end
end
