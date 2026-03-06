class CustomersController < ApplicationController
  before_action :require_enterprise_selected
  before_action :set_customer, only: %i[show edit update destroy]

  def index
    authorize Customer
    customers = current_enterprise.customers.order(created_at: :desc)

    if params[:q].present?
      query = "%#{params[:q].strip.downcase}%"
      customers = customers.where("LOWER(name) LIKE :q OR LOWER(tax_id) LIKE :q", q: query)
    end

    @pagy, @customers = pagy(customers)
  end

  def search
    authorize Customer, :index?
    query = params[:q].to_s.strip

    @customers = if query.present?
      current_enterprise.customers
                       .where("LOWER(name) LIKE :query OR tax_id LIKE :query", query: "%#{query.downcase}%")
                       .order(:name)
                       .limit(20)
    else
      current_enterprise.customers.order(:name).limit(20)
    end

    respond_to do |format|
      format.turbo_stream
      format.json do
        render json: @customers.map { |c| { id: c.id, display: c.combobox_display, ubigeo_id: c.ubigeo_id } }
      end
    end
  end

  def show
    authorize @customer

    respond_to do |format|
      format.html
      format.json do
        render json: {
          id: @customer.id,
          name: @customer.name,
          ubigeo_id: @customer.ubigeo_id,
          ubigeo_display: @customer.ubigeo&.combobox_display
        }
      end
    end
  end

  def new
    authorize Customer
    @customer = current_enterprise.customers.build
  end

  def create
    authorize Customer
    @customer = current_enterprise.customers.build(customer_params)

    if @customer.save
      redirect_to @customer, notice: "Cliente creado exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer
  end

  def update
    authorize @customer

    if @customer.update(customer_params)
      redirect_to @customer, notice: "Cliente actualizado exitosamente."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer
    @customer.destroy
    redirect_to customers_path, notice: "Cliente eliminado exitosamente."
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_customer
    @customer = current_enterprise.customers.find(params[:id])
  end

  def customer_params
    params.require(:customer).permit(
      :name,
      :tax_id,
      :tax_id_type,
      :email,
      :phone_number,
      :address,
      :ubigeo_id,
      :credit_limit,
      :payment_terms
    )
  end
end
