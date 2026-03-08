class Admin::EnterprisesController < Admin::ApplicationController
  def new
    @enterprise = Enterprise.new
    @enterprise.build_settings
  end

  def create
    service = CreateNewEnterpriseClient.new(params.require(:enterprise), user_id: Current.user.id)
    service.call

    if service.valid?
      redirect_to root_path, notice: "Empresa creada exitosamente."
    else
      @enterprise = Enterprise.new(enterprise_params)
      @enterprise.build_settings unless @enterprise.settings

      flash.now[:alert] = service.errors.join(", ")
      render :new, status: :unprocessable_entity
    end
  end

  private

  def enterprise_params
    params.require(:enterprise).permit(:tax_id, :enterprise_type, :social_reason, :comercial_name, :address, :email, :phone_number, :logo,
                                       settings_attributes: [ :primary_color, :secondary_color ])
  end
end
