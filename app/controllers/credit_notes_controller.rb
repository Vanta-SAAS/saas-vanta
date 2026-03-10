class CreditNotesController < ApplicationController
  include PdfExportable

  before_action :require_enterprise_selected
  before_action :set_credit_note, only: %i[show emit_document retry_document sunat_pdf sunat_xml]

  def index
    authorize CreditNote
    credit_notes = current_enterprise.credit_notes
                                     .includes(:sale, :created_by)
                                     .order(created_at: :desc)

    if params[:q].present?
      query = "%#{params[:q].strip.downcase}%"
      credit_notes = credit_notes.where("LOWER(credit_notes.code) LIKE :q", q: query)
    end

    @pagy, @credit_notes = pagy(credit_notes)
  end

  def show
    authorize @credit_note
  end

  def new
    authorize CreditNote
    @sale = current_enterprise.sales.find(params[:sale_id])

    sale_doc = @sale.current_sunat_document
    unless sale_doc&.sunat_uuid.present? && sale_doc&.accepted?
      redirect_to @sale, alert: "La venta debe tener un comprobante aceptado por SUNAT para emitir nota de credito."
      return
    end

    @credit_note = current_enterprise.credit_notes.build(
      sale: @sale,
      code: CreditNote.generate_next_code(current_enterprise),
      created_by: Current.user,
      status: :pending
    )

    # Pre-fill items from the sale
    @sale.items.includes(:product).each do |sale_item|
      @credit_note.items.build(
        description: sale_item.product.name,
        quantity: sale_item.quantity,
        unit_price: sale_item.unit_price,
        item_type: "product",
        tax_type: "gravado"
      )
    end
  end

  def create
    authorize CreditNote

    @sale = current_enterprise.sales.find(params[:credit_note][:sale_id])
    @credit_note = current_enterprise.credit_notes.build(credit_note_params)
    @credit_note.sale = @sale
    @credit_note.created_by = Current.user
    @credit_note.status = :pending

    unless credit_note_params[:items_attributes].present?
      @credit_note.errors.add(:base, "Debes agregar al menos un item")
      return render :new, status: :unprocessable_entity
    end

    if @credit_note.save
      redirect_to @credit_note, notice: "Nota de credito creada exitosamente."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def emit_document
    authorize @credit_note

    service = Sunat::EmitCreditNoteService.new(credit_note: @credit_note)
    service.call

    if service.valid?
      redirect_to @credit_note, notice: "Nota de credito emitida exitosamente. Estado: #{@credit_note.sunat_status}"
    else
      redirect_to @credit_note, alert: service.errors_message
    end
  end

  def retry_document
    authorize @credit_note

    service = Sunat::EmitCreditNoteService.new(credit_note: @credit_note)
    service.call

    if service.valid?
      redirect_to @credit_note, notice: "Reintento enviado. Estado: #{@credit_note.sunat_status}"
    else
      redirect_to @credit_note, alert: service.errors_message
    end
  end

  def sunat_pdf
    authorize @credit_note, :show?

    qr_text = @credit_note.sunat_response_data&.dig("qr_text")
    if qr_text.present?
      qr = RQRCode::QRCode.new(qr_text, level: :l)
      png = qr.as_png(size: 600, border_modules: 1)
      @qr_tempfile = Tempfile.new([ "qr", ".png" ])
      @qr_tempfile.binmode
      @qr_tempfile.write(png.to_s)
      @qr_tempfile.close
      @qr_file_path = @qr_tempfile.path
    end

    generate_pdf(@credit_note, template: "credit_notes/sunat_pdf", filename: "#{@credit_note.sunat_formatted_number || @credit_note.code}.pdf")
  ensure
    @qr_tempfile&.unlink
  end

  def sunat_xml
    authorize @credit_note, :show?

    send_data @credit_note.sunat_xml,
      filename: "#{@credit_note.sunat_formatted_number || @credit_note.code}.xml",
      type: "application/xml",
      disposition: "attachment"
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?
    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_credit_note
    @credit_note = current_enterprise.credit_notes.find(params[:id])
  end

  def credit_note_params
    params.require(:credit_note).permit(
      :code,
      :reason_code,
      :description,
      items_attributes: [ :id, :description, :quantity, :unit_price, :item_type, :tax_type, :_destroy ]
    )
  end
end
