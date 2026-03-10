class CustomerQuotesController < ApplicationController
  include PdfExportable

  before_action :require_enterprise_selected
  before_action -> { require_module!("ventas.cotizaciones") }
  before_action :set_customer_quote, only: %i[show edit update destroy accept reject expire pdf]

  def index
    authorize CustomerQuote
    customer_quotes = current_enterprise.customer_quotes
                                        .includes(:customer, :seller, :created_by)
                                        .order(created_at: :desc)

    if params[:q].present?
      query = "%#{params[:q].strip.downcase}%"
      customer_quotes = customer_quotes.joins(:customer).where("LOWER(customer_quotes.code) LIKE :q OR LOWER(customers.name) LIKE :q", q: query)
    end

    @pagy, @customer_quotes = pagy(customer_quotes)
  end

  def show
    authorize @customer_quote
  end

  def new
    authorize CustomerQuote
    @customer_quote = current_enterprise.customer_quotes.build(
      code: CustomerQuote.generate_next_code(current_enterprise),
      issue_date: Date.current,
      expiration_date: 15.days.from_now.to_date,
      created_by: Current.user,
      seller: Current.user
    )
    @show_seller_selector = !current_user_is_seller_only?
    @credit_enabled = current_enterprise.module_enabled?("ventas.credito_clientes")
  end

  def create
    authorize CustomerQuote

    @customer_quote = current_enterprise.customer_quotes.build(customer_quote_params)
    @customer_quote.status = :pending
    @customer_quote.created_by = Current.user

    # If user is seller role, force themselves as seller
    if current_user_is_seller_only?
      @customer_quote.seller = Current.user
    end

    unless customer_quote_params[:items_attributes].present?
      @customer_quote.errors.add(:base, "Debes agregar al menos un producto")
      @show_seller_selector = !current_user_is_seller_only?
      @credit_enabled = current_enterprise.module_enabled?("ventas.credito_clientes")
      return render :new, status: :unprocessable_entity
    end

    if @customer_quote.save
      redirect_to @customer_quote, notice: "Cotizacion creada exitosamente."
    else
      @show_seller_selector = !current_user_is_seller_only?
      @credit_enabled = current_enterprise.module_enabled?("ventas.credito_clientes")
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @customer_quote
    @show_seller_selector = !current_user_is_seller_only?
    @credit_enabled = current_enterprise.module_enabled?("ventas.credito_clientes")

    unless @customer_quote.can_edit?
      redirect_to @customer_quote, alert: "No se puede editar una cotizacion que no esta pendiente."
    end
  end

  def update
    authorize @customer_quote

    unless @customer_quote.can_edit?
      redirect_to @customer_quote, alert: "No se puede editar una cotizacion que no esta pendiente."
      return
    end

    update_params = customer_quote_params
    # If user is seller role, don't allow changing seller
    if current_user_is_seller_only?
      update_params = update_params.except(:seller_id)
    end

    if @customer_quote.update(update_params)
      redirect_to @customer_quote, notice: "Cotizacion actualizada exitosamente."
    else
      @show_seller_selector = !current_user_is_seller_only?
      @credit_enabled = current_enterprise.module_enabled?("ventas.credito_clientes")
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @customer_quote

    if @customer_quote.pending?
      @customer_quote.destroy
      redirect_to customer_quotes_path, notice: "Cotizacion eliminada."
    else
      redirect_to @customer_quote, alert: "Solo se pueden eliminar cotizaciones pendientes."
    end
  end

  # Status transitions
  def accept
    authorize @customer_quote

    if @customer_quote.accept!
      redirect_to @customer_quote, notice: "Cotizacion aceptada."
    else
      redirect_to @customer_quote, alert: "No se pudo aceptar la cotizacion."
    end
  end

  def reject
    authorize @customer_quote

    if @customer_quote.reject!
      redirect_to @customer_quote, notice: "Cotizacion rechazada."
    else
      redirect_to @customer_quote, alert: "No se pudo rechazar la cotizacion."
    end
  end

  def expire
    authorize @customer_quote

    if @customer_quote.expire!
      redirect_to @customer_quote, notice: "Cotizacion marcada como expirada."
    else
      redirect_to @customer_quote, alert: "No se pudo marcar como expirada."
    end
  end

  def prefill
    authorize CustomerQuote, :create?

    data_service = CustomerQuotes::HistoricalDataRecoverer.new(
      enterprise: current_enterprise,
      customer_id: params[:customer_id]
    )
    data_service.call

    price_service = CustomerQuotes::HistoricalPriceRecoverer.new(
      enterprise: current_enterprise,
      customer_id: params[:customer_id]
    )
    price_service.call

    render json: {
      last_notes: data_service.last_quote_data[:last_notes],
      price_history: price_service.price_history
    }
  end

  def pdf
    authorize @customer_quote, :show?

    generate_pdf(@customer_quote, template: "customer_quotes/pdf")
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_customer_quote
    @customer_quote = current_enterprise.customer_quotes.find(params[:id])
  end

  def customer_quote_params
    params.require(:customer_quote).permit(
      :code,
      :customer_id,
      :seller_id,
      :destination_id,
      :issue_date,
      :expiration_date,
      :payment_condition,
      :notes,
      items_attributes: [ :id, :product_id, :quantity, :unit_price, :_destroy ],
      installments_attributes: [ :id, :installment_number, :amount, :due_date, :_destroy ]
    )
  end

  def current_user_is_seller_only?
    roles = Current.user.roles_for(current_enterprise)
    roles.include?("seller") && !roles.include?("super_admin") && !roles.include?("admin") && !Current.user.super_admin?
  end
end
