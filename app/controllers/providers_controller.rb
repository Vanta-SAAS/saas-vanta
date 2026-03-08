class ProvidersController < ApplicationController
  before_action :require_enterprise_selected
  before_action -> { require_module!(:compras) }
  before_action :set_provider, only: %i[show edit update destroy]

  def index
    authorize Provider
    providers = current_enterprise.providers.order(created_at: :desc)

    if params[:q].present?
      query = "%#{params[:q].strip.downcase}%"
      providers = providers.where("LOWER(name) LIKE :q OR LOWER(ruc) LIKE :q", q: query)
    end

    @pagy, @providers = pagy(providers)
  end

  def search
    authorize Provider, :index?
    query = params[:q].to_s.strip

    @providers = if query.present?
      current_enterprise.providers
                       .where("LOWER(name) LIKE :query OR tax_id LIKE :query", query: "%#{query.downcase}%")
                       .order(:name)
                       .limit(20)
    else
      current_enterprise.providers.order(:name).limit(20)
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  def show
    authorize @provider
  end

  def new
    authorize Provider
    @provider = current_enterprise.providers.build
  end

  def create
    authorize Provider
    @provider = current_enterprise.providers.build(provider_params)

    if @provider.save
      redirect_to @provider, notice: "Proveedor creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @provider
  end

  def update
    authorize @provider

    if @provider.update(provider_params)
      redirect_to @provider, notice: "Proveedor actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @provider
    @provider.destroy
    redirect_to providers_path, notice: "Proveedor eliminado exitosamente."
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_provider
    @provider = current_enterprise.providers.find(params[:id])
  end

  def provider_params
    params.require(:provider).permit(
      :name,
      :tax_id,
      :email,
      :phone_number,
      :ubigeo_id
    )
  end
end
