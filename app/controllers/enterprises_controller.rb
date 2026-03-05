class EnterprisesController < ApplicationController
  layout "auth", only: [ :index ]
  skip_enterprise_selection only: [ :index, :select ]

  def index
    @enterprises = Current.user.enterprises
  end

  def select
    if Current.user.enterprises.exists?(params[:id])
      session[:enterprise_id] = params[:id]
      Current.session.update!(enterprise_id: params[:id])
      redirect_to root_path
    else
      redirect_to enterprises_path, alert: "Invalid enterprise selected."
    end
  end

  def edit
    @enterprise = current_enterprise
    authorize @enterprise
    @enterprise.build_settings unless @enterprise.settings
  end

  def update
    @enterprise = current_enterprise
    authorize @enterprise

    if @enterprise.update(enterprise_params)
      redirect_to edit_enterprise_path(@enterprise), notice: "Datos de la empresa actualizados correctamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  private

  def enterprise_params
    params.require(:enterprise).permit(
      :comercial_name, :tax_id, :social_reason, :address, :email, :phone_number, :logo, :ubigeo_id,
      settings_attributes: [ :id, :use_stock, :dropshipping_enabled, :primary_color, :secondary_color ]
    )
  end
end
