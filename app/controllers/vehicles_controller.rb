class VehiclesController < ApplicationController
  before_action :require_enterprise_selected
  before_action :set_vehicle, only: %i[edit update destroy]

  def index
    authorize Vehicle
    vehicles = current_enterprise.vehicles.order(created_at: :desc)
    @pagy, @vehicles = pagy(vehicles)
  end

  def new
    authorize Vehicle
    @vehicle = current_enterprise.vehicles.build
  end

  def create
    authorize Vehicle
    @vehicle = current_enterprise.vehicles.build(vehicle_params)

    if @vehicle.save
      respond_to do |format|
        format.turbo_stream do
          render turbo_stream: turbo_stream.replace(
            "vehicle-select",
            partial: "dispatch_guides/vehicle_select",
            locals: { vehicles: current_enterprise.vehicles.active.order(:plate), selected_vehicle_id: @vehicle.id }
          )
        end
        format.html { redirect_to vehicles_path, notice: "Vehiculo registrado exitosamente." }
      end
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @vehicle
  end

  def update
    authorize @vehicle

    if @vehicle.update(vehicle_params)
      redirect_to vehicles_path, notice: "Vehiculo actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @vehicle
    @vehicle.destroy
    redirect_to vehicles_path, notice: "Vehiculo eliminado exitosamente."
  end

  private

  def set_vehicle
    @vehicle = current_enterprise.vehicles.find(params[:id])
  end

  def vehicle_params
    params.require(:vehicle).permit(:plate, :brand, :model, :status)
  end

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end
end
