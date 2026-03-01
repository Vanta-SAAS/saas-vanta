class SalesController < ApplicationController
  include PdfExportable

  before_action :require_enterprise_selected
  before_action :set_sale, only: %i[show edit update destroy confirm cancel pdf sunat_pdf sunat_xml generate_purchase_orders emit_document check_sunat_status retry_document]

  def index
    authorize Sale
    sales = current_enterprise.sales
                              .includes(:customer, :seller, :created_by)
                              .order(created_at: :desc)
    @pagy, @sales = pagy(sales)
  end

  def show
    authorize @sale
  end

  def new
    authorize Sale
    @sale = current_enterprise.sales.build(
      code: Sale.generate_next_code(current_enterprise),
      issue_date: Date.current,
      created_by: Current.user,
      seller: Current.user
    )
    @show_seller_selector = !current_user_is_seller_only?
  end

  def create
    authorize Sale

    @sale = current_enterprise.sales.build(sale_params)
    @sale.status = :pending
    @sale.created_by = Current.user

    if current_user_is_seller_only?
      @sale.seller = Current.user
    end

    unless sale_params[:items_attributes].present?
      @sale.errors.add(:base, "Debes agregar al menos un producto")
      @show_seller_selector = !current_user_is_seller_only?
      return render :new, status: :unprocessable_entity
    end

    if @sale.save
      redirect_to @sale, notice: "Venta creada exitosamente."
    else
      @show_seller_selector = !current_user_is_seller_only?
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @sale
    @show_seller_selector = !current_user_is_seller_only?

    unless @sale.can_edit?
      redirect_to @sale, alert: "No se puede editar una venta que no esta pendiente."
    end
  end

  def update
    authorize @sale

    unless @sale.can_edit?
      redirect_to @sale, alert: "No se puede editar una venta que no esta pendiente."
      return
    end

    update_params = sale_params
    if current_user_is_seller_only?
      update_params = update_params.except(:seller_id)
    end

    if @sale.update(update_params)
      redirect_to @sale, notice: "Venta actualizada exitosamente."
    else
      @show_seller_selector = !current_user_is_seller_only?
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @sale

    if @sale.pending?
      @sale.destroy
      redirect_to sales_path, notice: "Venta eliminada."
    else
      redirect_to @sale, alert: "Solo se pueden eliminar ventas pendientes."
    end
  end

  def confirm
    authorize @sale

    if @sale.confirm!
      redirect_to @sale, notice: "Venta confirmada. Stock actualizado."
    else
      redirect_to @sale, alert: @sale.errors.full_messages.join(", ")
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @sale, alert: e.message
  end

  def cancel
    authorize @sale

    if @sale.cancel!
      redirect_to @sale, notice: "Venta cancelada."
    else
      redirect_to @sale, alert: "No se pudo cancelar la venta."
    end
  end

  def generate_purchase_orders
    authorize @sale

    if @sale.generate_purchase_orders!(created_by: Current.user)
      redirect_to @sale, notice: "Ordenes de compra generadas exitosamente."
    else
      redirect_to @sale, alert: @sale.errors.full_messages.first || "No se pudieron generar las ordenes de compra."
    end
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @sale, alert: e.message
  end

  def emit_document
    authorize @sale

    service = Sunat::EmitDocumentService.new(sale: @sale)
    service.call

    if service.valid?
      doc_type = @sale.sunat_document_type == "01" ? "Factura" : "Boleta"
      redirect_to @sale, notice: "#{doc_type} emitida exitosamente. Estado: #{@sale.sunat_status}"
    else
      redirect_to @sale, alert: service.errors_message
    end
  end

  def check_sunat_status
    authorize @sale, :show?

    service = Sunat::CheckStatusService.new(sale: @sale)
    service.call

    if service.valid?
      redirect_to @sale, notice: "Estado actualizado: #{@sale.sunat_status}"
    else
      redirect_to @sale, alert: service.errors_message
    end
  end

  def retry_document
    authorize @sale

    service = Sunat::RetryDocumentService.new(sale: @sale)
    service.call

    if service.valid?
      redirect_to @sale, notice: "Reintento enviado. Estado: #{@sale.sunat_status}"
    else
      redirect_to @sale, alert: service.errors_message
    end
  end

  def pdf
    authorize @sale, :show?

    generate_pdf(@sale, template: "sales/pdf")
  end

  def sunat_pdf
    authorize @sale, :show?

    qr_text = @sale.sunat_response_data&.dig("qr_text")
    if qr_text.present?
      qr = RQRCode::QRCode.new(qr_text, level: :l)
      png = qr.as_png(size: 600, border_modules: 1)
      @qr_tempfile = Tempfile.new([ "qr", ".png" ])
      @qr_tempfile.binmode
      @qr_tempfile.write(png.to_s)
      @qr_tempfile.close
      @qr_file_path = @qr_tempfile.path
    end

    generate_pdf(@sale, template: "sales/sunat_pdf", filename: "#{@sale.sunat_series}-#{@sale.sunat_number}.pdf")
  ensure
    @qr_tempfile&.unlink
  end

  def sunat_xml
    authorize @sale, :show?

    send_data @sale.sunat_xml,
      filename: "#{@sale.sunat_series}-#{@sale.sunat_number}.xml",
      type: "application/xml",
      disposition: "attachment"
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_sale
    @sale = current_enterprise.sales.find(params[:id])
  end

  def sale_params
    params.require(:sale).permit(
      :code,
      :customer_id,
      :seller_id,
      :destination_id,
      :issue_date,
      :notes,
      items_attributes: [ :id, :product_id, :quantity, :unit_price, :_destroy ]
    )
  end

  def current_user_is_seller_only?
    roles = Current.user.roles_for(current_enterprise)
    roles.include?("seller") && !roles.include?("super_admin") && !roles.include?("admin") && !Current.user.super_admin?
  end
end
