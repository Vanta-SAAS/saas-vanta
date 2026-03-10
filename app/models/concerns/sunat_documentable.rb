module SunatDocumentable
  extend ActiveSupport::Concern

  included do
    has_many :sunat_documents, as: :documentable, dependent: :destroy
  end

  # The current (latest non-voided) SUNAT document
  def current_sunat_document
    sunat_documents.active.order(created_at: :desc).first
  end

  # --- Delegated accessors (read from current_sunat_document) ---

  def sunat_uuid
    current_sunat_document&.sunat_uuid
  end

  def sunat_status
    current_sunat_document&.sunat_status
  end

  def sunat_document_type
    current_sunat_document&.sunat_document_type
  end

  def sunat_series
    current_sunat_document&.sunat_series
  end

  def sunat_number
    current_sunat_document&.sunat_number
  end

  def sunat_xml
    current_sunat_document&.sunat_xml
  end

  def sunat_cdr_code
    current_sunat_document&.sunat_cdr_code
  end

  def sunat_cdr_description
    current_sunat_document&.sunat_cdr_description
  end

  def sunat_hash
    current_sunat_document&.sunat_hash
  end

  def sunat_qr_image
    current_sunat_document&.sunat_qr_image
  end

  def sunat_response_data
    current_sunat_document&.sunat_response_data
  end

  # --- Derived helpers ---

  def sunat_formatted_number
    current_sunat_document&.formatted_number
  end

  def sunat_document_type_label
    current_sunat_document&.document_type_label
  end

  def sunat_status_badge_class
    current_sunat_document&.status_badge_class || "badge-secondary"
  end

  def can_retry_document?
    current_sunat_document&.can_retry? || false
  end
end
