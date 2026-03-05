class DispatchGuidesController < ApplicationController
  include PdfExportable

  before_action :require_enterprise_selected
  before_action :set_dispatch_guide, only: %i[show edit update destroy cancel emit_document check_sunat_status retry_document pdf sunat_xml]

  def index
    authorize DispatchGuide
    guides = current_enterprise.dispatch_guides
                               .includes(:created_by, :vehicle, :driver)
                               .order(created_at: :desc)
    @pagy, @dispatch_guides = pagy(guides)
  end

  def show
    authorize @dispatch_guide
  end

  def new
    authorize DispatchGuide

    @dispatch_guide = current_enterprise.dispatch_guides.build(
      code: DispatchGuide.generate_next_code(current_enterprise),
      issue_date: Date.current,
      transfer_date: Date.current,
      created_by: Current.user,
      guide_type: params[:guide_type] || "grr",
      transport_modality: "private"
    )

    if params[:sale_id].present?
      sale = current_enterprise.sales.find_by(id: params[:sale_id])
      if sale && !sale.has_goods?
        redirect_to sale, alert: "No se puede crear una guia de remision para ventas que solo contienen servicios."
        return
      end
      prefill_from_sale
    end

    load_form_data
  end

  def create
    authorize DispatchGuide

    @dispatch_guide = current_enterprise.dispatch_guides.build(dispatch_guide_params)
    @dispatch_guide.created_by = Current.user
    @dispatch_guide.status = :draft

    unless dispatch_guide_params[:items_attributes].present?
      @dispatch_guide.errors.add(:base, "Debes agregar al menos un item")
      load_form_data
      return render :new, status: :unprocessable_entity
    end

    unless @dispatch_guide.save
      load_form_data
      return render :new, status: :unprocessable_entity
    end

    service = Sunat::EmitDispatchGuideService.new(dispatch_guide: @dispatch_guide)
    service.call

    if service.valid?
      doc_type = @dispatch_guide.grr? ? "Guia Remitente" : "Guia Transportista"
      redirect_to @dispatch_guide, notice: "#{doc_type} emitida exitosamente ante SUNAT."
    else
      @dispatch_guide.destroy
      @dispatch_guide = current_enterprise.dispatch_guides.build(dispatch_guide_params)
      @dispatch_guide.created_by = Current.user
      @dispatch_guide.errors.add(:base, "Error SUNAT: #{service.errors_message}")
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @dispatch_guide

    unless @dispatch_guide.can_edit?
      redirect_to @dispatch_guide, alert: "Solo se pueden editar guias en borrador."
      return
    end

    load_form_data
  end

  def update
    authorize @dispatch_guide

    unless @dispatch_guide.can_edit?
      redirect_to @dispatch_guide, alert: "Solo se pueden editar guias en borrador."
      return
    end

    if @dispatch_guide.update(dispatch_guide_params)
      redirect_to @dispatch_guide, notice: "Guia de remision actualizada exitosamente."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @dispatch_guide

    if @dispatch_guide.draft?
      @dispatch_guide.destroy
      redirect_to dispatch_guides_path, notice: "Guia eliminada."
    else
      redirect_to @dispatch_guide, alert: "Solo se pueden eliminar guias en borrador."
    end
  end

  def cancel
    authorize @dispatch_guide

    if @dispatch_guide.cancel!
      redirect_to @dispatch_guide, notice: "Guia cancelada."
    else
      redirect_to @dispatch_guide, alert: "No se pudo cancelar la guia."
    end
  end

  def emit_document
    authorize @dispatch_guide

    service = Sunat::EmitDispatchGuideService.new(dispatch_guide: @dispatch_guide)
    service.call

    if service.valid?
      doc_type = @dispatch_guide.grr? ? "Guia Remitente" : "Guia Transportista"
      redirect_to @dispatch_guide, notice: "#{doc_type} emitida exitosamente. Estado: #{@dispatch_guide.sunat_status}"
    else
      redirect_to @dispatch_guide, alert: service.errors_message
    end
  end

  def check_sunat_status
    authorize @dispatch_guide, :show?

    service = Sunat::CheckDispatchGuideStatusService.new(dispatch_guide: @dispatch_guide)
    service.call

    if service.valid?
      redirect_to @dispatch_guide, notice: "Estado actualizado: #{@dispatch_guide.sunat_status}"
    else
      redirect_to @dispatch_guide, alert: service.errors_message
    end
  end

  def retry_document
    authorize @dispatch_guide

    service = Sunat::RetryDispatchGuideService.new(dispatch_guide: @dispatch_guide)
    service.call

    if service.valid?
      redirect_to @dispatch_guide, notice: "Reintento enviado. Estado: #{@dispatch_guide.sunat_status}"
    else
      redirect_to @dispatch_guide, alert: service.errors_message
    end
  end

  def pdf
    authorize @dispatch_guide, :show?

    qr_text = @dispatch_guide.sunat_response_data&.dig("qr_text")
    if qr_text.present?
      qr = RQRCode::QRCode.new(qr_text, level: :l)
      png = qr.as_png(size: 600, border_modules: 1)
      @qr_tempfile = Tempfile.new([ "qr", ".png" ])
      @qr_tempfile.binmode
      @qr_tempfile.write(png.to_s)
      @qr_tempfile.close
      @qr_file_path = @qr_tempfile.path
    end

    generate_pdf(@dispatch_guide, template: "dispatch_guides/pdf", filename: "#{@dispatch_guide.sunat_formatted_number || @dispatch_guide.code}.pdf")
  ensure
    @qr_tempfile&.unlink
  end

  def sunat_xml
    authorize @dispatch_guide, :show?

    send_data @dispatch_guide.sunat_xml,
      filename: "#{@dispatch_guide.sunat_formatted_number}.xml",
      type: "application/xml",
      disposition: "attachment"
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_dispatch_guide
    @dispatch_guide = current_enterprise.dispatch_guides.find(params[:id])
  end

  def dispatch_guide_params
    params.require(:dispatch_guide).permit(
      :code, :guide_type, :issue_date, :transfer_date,
      :transfer_reason, :transport_modality, :gross_weight, :notes,
      :departure_ubigeo_id, :departure_address,
      :arrival_ubigeo_id, :arrival_address,
      :recipient_doc_type, :recipient_doc_number, :recipient_name,
      :vehicle_id, :driver_id,
      :carrier_id, :carrier_ruc, :carrier_name,
      :shipper_doc_type, :shipper_doc_number, :shipper_name,
      items_attributes: [ :id, :description, :quantity, :unit_code, :product_id, :_destroy ]
    )
  end

  def load_form_data
    @vehicles = current_enterprise.vehicles.active.order(:plate)
    @carriers = current_enterprise.carriers.active.order(:name)
    @drivers = current_enterprise.users
                                 .joins(user_enterprises: { user_enterprise_roles: :role })
                                 .where(roles: { slug: "driver" })
                                 .where(user_enterprises: { enterprise_id: current_enterprise.id })
                                 .distinct
  end

  def prefill_from_sale
    sale = current_enterprise.sales.find_by(id: params[:sale_id])
    return unless sale

    @dispatch_guide.sourceable = sale
    @dispatch_guide.transfer_reason = :venta
    @dispatch_guide.recipient_doc_type = sale.customer.tax_id_type == "ruc" ? "ruc" : "dni"
    @dispatch_guide.recipient_doc_number = sale.customer.tax_id
    @dispatch_guide.recipient_name = sale.customer.name
    @dispatch_guide.arrival_address = sale.customer.address
    @dispatch_guide.arrival_ubigeo = sale.customer.ubigeo
    @dispatch_guide.departure_address = current_enterprise.address
    @dispatch_guide.departure_ubigeo = current_enterprise.ubigeo

    sale.items.includes(:product).each do |sale_item|
      next if sale_item.product.service?

      @dispatch_guide.items.build(
        description: sale_item.product.name,
        quantity: sale_item.quantity,
        unit_code: "NIU",
        product_id: sale_item.product_id
      )
    end
  end
end
