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

  belongs_to :enterprise
  belongs_to :sale
  belongs_to :created_by, class_name: "User"

  has_many :items, class_name: "CreditNoteItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  enum :status, { pending: "pending", emitted: "emitted", error: "error" }

  validates :code, presence: true, uniqueness: { scope: :enterprise_id }
  validates :reason_code, presence: true, inclusion: { in: REASON_CODES.keys }
  validates :description, presence: true

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

  def can_emit?
    doc = sale.current_sunat_document
    pending? && items.any? && doc.present? && doc.accepted? && !doc.voided?
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

  def calculate_totals
    self.total = items.reject(&:marked_for_destruction?).sum { |item|
      (item.quantity || 0) * (item.unit_price || 0)
    }
    self.subtotal = PeruTax.base_amount(total)
    self.tax = PeruTax.extract_igv(total)
  end
end
