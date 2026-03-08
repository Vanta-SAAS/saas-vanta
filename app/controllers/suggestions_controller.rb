class SuggestionsController < ApplicationController
  before_action :require_enterprise_selected

  def new
    @suggestion = Suggestion.new
  end

  def create
    @suggestion = Suggestion.new(suggestion_params)
    @suggestion.enterprise = current_enterprise
    @suggestion.user = Current.user

    if @suggestion.save
      SuggestionMailer.with(suggestion: @suggestion).new_suggestion.deliver_later(queue: "low_priority")
      redirect_to new_suggestion_path, notice: "Gracias por tu sugerencia. Tu opinion nos ayuda a mejorar."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def suggestion_params
    params.require(:suggestion).permit(:body, :wants_contact, :contact_email, :contact_phone)
  end
end
