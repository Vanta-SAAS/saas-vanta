class SunatDocument < ApplicationRecord
  belongs_to :documentable, polymorphic: true

  scope :active, -> { where(voided: false) }
  scope :voided, -> { where(voided: true) }

  def formatted_number
    return nil unless sunat_series.present? && sunat_number.present?
    "#{sunat_series}-#{sunat_number.to_s.rjust(8, '0')}"
  end

  def document_type_label
    case sunat_document_type
    when "01" then "Factura"
    when "03" then "Boleta de Venta"
    when "07" then "Nota de Credito"
    when "09" then "Guia Remitente"
    when "31" then "Guia Transportista"
    else sunat_document_type
    end
  end

  def status_badge_class
    case sunat_status
    when "ACCEPTED" then "badge-success"
    when "REJECTED", "ERROR" then "badge-destructive"
    when "SIGNED", "CREATED" then "badge-secondary"
    else "badge-secondary"
    end
  end

  def accepted?
    sunat_status == "ACCEPTED"
  end

  def can_retry?
    sunat_uuid.present? && sunat_status.in?(%w[ERROR REJECTED])
  end

  def void!
    update!(voided: true)
  end
end
