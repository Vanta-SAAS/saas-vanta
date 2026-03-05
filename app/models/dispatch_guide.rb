class DispatchGuide < ApplicationRecord
  belongs_to :enterprise
  belongs_to :created_by, class_name: "User"
  belongs_to :departure_ubigeo, class_name: "Ubigeo", optional: true
  belongs_to :arrival_ubigeo, class_name: "Ubigeo", optional: true
  belongs_to :vehicle, optional: true
  belongs_to :driver, class_name: "User", optional: true
  belongs_to :carrier, optional: true
  belongs_to :sourceable, polymorphic: true, optional: true

  has_many :items, class_name: "DispatchGuideItem", dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  # Enums
  enum :guide_type, { grr: "grr", grt: "grt" }
  enum :status, { draft: "draft", emitted: "emitted", cancelled: "cancelled" }
  enum :transport_modality, { private_transport: "private", public_transport: "public" }
  enum :transfer_reason, {
    venta: "venta",
    compra: "compra",
    traslado_entre_establecimientos: "traslado_entre_establecimientos",
    importacion: "importacion",
    exportacion: "exportacion",
    otros: "otros"
  }

  # Validations
  validates :code, presence: true, uniqueness: { scope: :enterprise_id }
  validates :issue_date, :transfer_date, :guide_type, :transfer_reason, :transport_modality, presence: true
  validates :gross_weight, numericality: { greater_than: 0 }, allow_nil: true
  validates :departure_address, :arrival_address, presence: true
  validates :recipient_name, :recipient_doc_number, :recipient_doc_type, presence: true, if: :grr?
  validates :shipper_name, :shipper_doc_number, :shipper_doc_type, presence: true, if: :grt?
  validates :vehicle, :driver, presence: true, if: :private_transport?
  validates :carrier, presence: true, if: :public_transport?

  # Callbacks
  before_save :denormalize_carrier_data

  # Code generation
  def self.generate_next_code(enterprise)
    current_year = Date.current.year
    last_record = enterprise.dispatch_guides
      .where("code LIKE ?", "GR-%-#{current_year}")
      .order(created_at: :desc)
      .first
    last_number = last_record&.code&.split("-")&.second.to_i || 0
    "GR-#{(last_number + 1).to_s.rjust(4, '0')}-#{current_year}"
  end

  # Status helpers
  def can_edit?
    draft?
  end

  def can_cancel?
    draft?
  end

  def can_emit_document?
    draft? && sunat_uuid.blank? &&
      enterprise.settings&.sunat_api_key.present? &&
      enterprise.settings&.sunat_certificate_uploaded? &&
      items.any?
  end

  def can_retry_document?
    sunat_uuid.present? && sunat_status.in?(%w[ERROR REJECTED])
  end

  def cancel!
    return false unless can_cancel?

    update!(status: :cancelled)
  end

  # SUNAT display helpers
  def sunat_formatted_number
    return nil unless sunat_series.present? && sunat_number.present?

    "#{sunat_series}-#{sunat_number.to_s.rjust(8, '0')}"
  end

  def sunat_document_type_label
    case sunat_document_type
    when "09" then "Guia Remitente"
    when "31" then "Guia Transportista"
    else sunat_document_type
    end
  end

  def sunat_status_badge_class
    case sunat_status
    when "ACCEPTED" then "badge-success"
    when "REJECTED", "ERROR" then "badge-destructive"
    when "SIGNED", "CREATED" then "badge-secondary"
    else "badge-secondary"
    end
  end

  def status_badge_class
    case status
    when "draft" then "badge-secondary"
    when "emitted" then "badge-success"
    when "cancelled" then "badge-destructive"
    else "badge-secondary"
    end
  end

  def status_label
    { "draft" => "Borrador", "emitted" => "Emitida", "cancelled" => "Cancelada" }[status] || status.humanize
  end

  def guide_type_label
    { "grr" => "Remitente", "grt" => "Transportista" }[guide_type] || guide_type
  end

  def transfer_reason_label
    {
      "venta" => "Venta",
      "compra" => "Compra",
      "traslado_entre_establecimientos" => "Traslado entre establecimientos",
      "importacion" => "Importacion",
      "exportacion" => "Exportacion",
      "otros" => "Otros"
    }[transfer_reason] || transfer_reason
  end

  def transport_modality_label
    { "private" => "Transporte privado", "public" => "Transporte publico" }[transport_modality] || transport_modality
  end

  private

  def denormalize_carrier_data
    return unless carrier.present?

    self.carrier_ruc = carrier.ruc
    self.carrier_name = carrier.name
  end
end
