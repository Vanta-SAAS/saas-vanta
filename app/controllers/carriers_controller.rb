class CarriersController < ApplicationController
  before_action :require_enterprise_selected
  before_action :set_carrier, only: %i[edit update destroy]

  def index
    authorize Carrier
    carriers = current_enterprise.carriers.order(created_at: :desc)
    @pagy, @carriers = pagy(carriers)
  end

  def new
    authorize Carrier
    @carrier = current_enterprise.carriers.build
  end

  def create
    authorize Carrier
    @carrier = current_enterprise.carriers.build(carrier_params)

    if @carrier.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "carrier-select",
            partial: "dispatch_guides/carrier_select",
            locals: { carriers: current_enterprise.carriers.active.order(:name), selected_carrier_id: @carrier.id }
          )
        end
        format.html { redirect_to carriers_path, notice: "Transportista registrado exitosamente." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @carrier
  end

  def update
    authorize @carrier

    if @carrier.update(carrier_params)
      redirect_to carriers_path, notice: "Transportista actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @carrier
    @carrier.destroy
    redirect_to carriers_path, notice: "Transportista eliminado exitosamente."
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_carrier
    @carrier = current_enterprise.carriers.find(params[:id])
  end

  def carrier_params
    params.require(:carrier).permit(:ruc, :name, :status)
  end
end
