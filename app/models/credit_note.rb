class CreditNote < ApplicationRecord
  include SunatDocumentable

  REASON_CODES = {
    "anulacion_de_la_operacion" => "Anulacion de la operacion",
    "anulacion_por_error_en_el_ruc" => "Anulacion por error en el RUC",
    "correccion_por_error_en_la_descripcion" => "Correccion por error en la descripcion",
    "descuento_global" => "Descuento global",
    "descuento_por_item" => "Descuento por item",
    "devolucion_total" => "Devolucion total",
    "devolucion_por_item" => "Devolucion por item",
    "bonificacion" => "Bonificacion",
    "disminucion_en_el_valor" => "Disminucion en el valor",
    "otros_conceptos" => "Otros conceptos",
    "correccion_del_monto_neto_pendiente_de_pago" => "Correccion del monto neto pendiente de pago"
  }.freeze

  VOIDING_REASON_CODES = %w[
    anulacion_de_la_operacion
    anulacion_por_error_en_el_ruc
    devolucion_total
  ].freeze

  ISSUE_DATE_MAX_BACKDATE_DAYS = 7

  belongs_to :enterprise
  belongs_to :sale
  belongs_to :created_by, class_name: "User"
  belongs_to :referenced_sunat_document, class_name: "SunatDocument", optional: true

  has_many :items, class_name: "CreditNoteItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  enum :status, { pending: "pending", emitted: "emitted", error: "error" }

  validates :code, presence: true, uniqueness: { scope: :enterprise_id }
  validates :reason_code, presence: true, inclusion: { in: REASON_CODES.keys }
  validates :description, presence: true
  validate :validate_issue_date
  validate :validate_referenced_sunat_document

  before_save :calculate_totals

  def self.generate_next_code(enterprise)
    current_year = Date.current.year
    last_record = enterprise.credit_notes
      .where("code LIKE ?", "NC-%-#{current_year}")
      .order(created_at: :desc)
      .first
    last_number = last_record&.code&.split("-")&.second.to_i || 0
    "NC-#{(last_number + 1).to_s.rjust(4, '0')}-#{current_year}"
  end

  def reason_label
    REASON_CODES[reason_code] || reason_code
  end

  def voids_reference?
    VOIDING_REASON_CODES.include?(reason_code)
  end

  def reference_sunat_document
    referenced_sunat_document || sale.current_sunat_document
  end

  def can_emit?
    doc = reference_sunat_document
    pending? && items.any? && doc.present? && doc.accepted?
  end

  def status_badge_class
    case status
    when "pending" then "badge-secondary"
    when "emitted" then "badge-success"
    when "error" then "badge-destructive"
    else "badge-secondary"
    end
  end

  def status_label
    { "pending" => "Pendiente", "emitted" => "Emitida", "error" => "Error" }[status] || status.humanize
  end

  private

  def validate_referenced_sunat_document
    return if referenced_sunat_document.blank?

    if sale.present? && referenced_sunat_document.documentable_id != sale.id
      errors.add(:referenced_sunat_document, "no pertenece a la venta")
      return
    end

    unless referenced_sunat_document.sunat_document_type.in?(%w[01 03])
      errors.add(:referenced_sunat_document, "debe ser una factura o boleta")
    end
  end

  def validate_issue_date
    return if issue_date.blank?

    today = Date.current
    if issue_date > today
      errors.add(:issue_date, "no puede ser una fecha futura")
    elsif (today - issue_date).to_i > ISSUE_DATE_MAX_BACKDATE_DAYS
      errors.add(:issue_date, "no puede ser mayor a #{ISSUE_DATE_MAX_BACKDATE_DAYS} dias en el pasado (regla SUNAT)")
    end
  end

  def calculate_totals
    self.total = items.reject(&:marked_for_destruction?).sum { |item|
      (item.quantity || 0) * (item.unit_price || 0)
    }
    self.subtotal = PeruTax.base_amount(total)
    self.tax = PeruTax.extract_igv(total)
  end
end
