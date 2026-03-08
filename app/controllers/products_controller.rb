class ProductsController < ApplicationController
  before_action :require_enterprise_selected
  before_action :validate_product_type_access, only: %i[index new]
  before_action :set_product, only: %i[show edit update destroy]

  def index
    authorize Product
    @product_type = resolve_default_product_type
    products = current_enterprise.products
                                 .where(product_type: @product_type)
                                 .includes(:provider)
                                 .order(created_at: :desc)

    if params[:q].present?
      query = "%#{params[:q].strip.downcase}%"
      products = products.where("LOWER(products.name) LIKE :q OR LOWER(products.sku) LIKE :q", q: query)
    end

    @pagy, @products = pagy(products)
  end

  def search
    authorize Product, :index?
    query = params[:q].to_s.strip

    @products = if query.present?
      current_enterprise.products
                       .where(status: :active)
                       .where("LOWER(name) LIKE :query OR LOWER(sku) LIKE :query", query: "%#{query.downcase}%")
                       .order(:name)
                       .limit(20)
    else
      current_enterprise.products.where(status: :active).order(:name).limit(20)
    end

    respond_to do |format|
      format.html { render layout: false }
    end
  end

  def show
    authorize @product
  end

  def new
    authorize Product
    @product = current_enterprise.products.build(product_type: params[:product_type] || "good")
    @providers = current_enterprise.providers
  end

  def create
    authorize Product
    @product = current_enterprise.products.build(product_params)

    if @product.save
      label = @product.service? ? "Servicio" : "Producto"
      redirect_to @product, notice: "#{label} creado exitosamente."
    else
      @providers = current_enterprise.providers
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @product
    @providers = current_enterprise.providers
  end

  def update
    authorize @product

    if @product.update(product_params)
      label = @product.service? ? "Servicio" : "Producto"
      redirect_to @product, notice: "#{label} actualizado exitosamente."
    else
      @providers = current_enterprise.providers
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @product
    label = @product.service? ? "Servicio" : "Producto"
    product_type = @product.product_type
    @product.destroy
    redirect_to products_path(product_type: product_type), notice: "#{label} eliminado exitosamente."
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def allowed_product_types
    types = []
    types << "good" if current_enterprise.sells_products?
    types << "service" if current_enterprise.sells_services?
    types
  end

  def validate_product_type_access
    requested = params[:product_type].presence
    return if requested.nil?

    unless allowed_product_types.include?(requested)
      redirect_to root_path, alert: "Este tipo de producto no está habilitado para tu empresa."
    end
  end

  def resolve_default_product_type
    requested = params[:product_type].presence
    return requested if requested && allowed_product_types.include?(requested)

    allowed_product_types.first || "good"
  end

  def set_product
    @product = current_enterprise.products.find(params[:id])
  end

  def product_params
    params.require(:product).permit(
      :name,
      :description,
      :sku,
      :source_type,
      :unit,
      :units_per_package,
      :capacity,
      :buy_price,
      :sell_cash_price,
      :sell_credit_price,
      :stock,
      :status,
      :provider_id,
      :product_type
    )
  end
end
