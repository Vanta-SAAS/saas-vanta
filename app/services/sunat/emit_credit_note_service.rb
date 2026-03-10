module Sunat
  class EmitCreditNoteService < BaseService
    attr_reader :sunat_result

    def initialize(credit_note:)
      super()
      @credit_note = credit_note
    end

    def call
      validate_prerequisites!
      return unless valid?

      settings = @credit_note.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      doc = @credit_note.current_sunat_document

      @sunat_result = if doc&.can_retry?
        client.retry_credit_note(doc.sunat_uuid)
      else
        client.create_credit_note(@credit_note)
      end

      sunat_status = @sunat_result["status"] || "CREATED"

      # Create or update the SunatDocument record
      sunat_doc = doc&.can_retry? ? doc : @credit_note.sunat_documents.build
      sunat_doc.update!(
        sunat_uuid: @sunat_result["uuid"] || @sunat_result["id"],
        sunat_status: sunat_status,
        sunat_document_type: "07",
        sunat_series: @sunat_result["series"],
        sunat_number: @sunat_result["correlative"] || @sunat_result["number"],
        sunat_xml: @sunat_result["xml_signed"],
        sunat_cdr_code: @sunat_result["cdr_code"],
        sunat_cdr_description: @sunat_result["cdr_description"],
        sunat_hash: @sunat_result["hash"],
        sunat_qr_image: @sunat_result["qr_image"],
        sunat_response_data: @sunat_result
      )

      @credit_note.update!(status: sunat_status == "ACCEPTED" ? :emitted : :error)

      if sunat_status == "ACCEPTED"
        # Void the sale's current SUNAT document
        sale_doc = @credit_note.sale.current_sunat_document
        sale_doc&.void!
      end

      if sunat_status == "REJECTED"
        description = @sunat_result["cdr_description"] || "Documento rechazado por SUNAT"
        add_error("SUNAT rechazo la nota de credito: #{description}")
        set_as_invalid!
        return
      end

      save_next_document_info!
    rescue Sunat::ApiClient::ServerErrorWithDocument => e
      save_document_from_error(e.document_data)
      add_error(e.message)
      set_as_invalid!
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    rescue ActiveRecord::RecordInvalid => e
      add_error(e.message)
      set_as_invalid!
    end

    private

    def validate_prerequisites!
      sale_doc = @credit_note.sale.current_sunat_document

      unless sale_doc.present? && sale_doc.accepted? && !sale_doc.voided?
        add_error("La venta debe tener un comprobante aceptado por SUNAT")
        set_as_invalid!
        return
      end

      unless @credit_note.items.any?
        add_error("La nota de credito debe tener al menos un item")
        set_as_invalid!
        return
      end

      settings = @credit_note.enterprise.settings
      unless settings&.sunat_api_key.present?
        add_error("La empresa no esta registrada en el servicio SUNAT")
        set_as_invalid!
        return
      end

      unless settings.sunat_certificate_uploaded?
        add_error("La empresa no tiene certificado digital cargado")
        set_as_invalid!
      end
    end

    def save_next_document_info!
      next_series = @sunat_result["next_document_series"]
      next_number = @sunat_result["next_document_number"]
      return unless next_series.present? || next_number.present?

      sale_doc = @credit_note.sale.current_sunat_document || @credit_note.sale.sunat_documents.order(created_at: :desc).first
      settings = @credit_note.enterprise.settings
      if sale_doc&.sunat_document_type == "01"
        settings.update!(
          sunat_series_nota_credito_factura: next_series,
          sunat_next_nota_credito_factura_number: next_number
        )
      else
        settings.update!(
          sunat_series_nota_credito_boleta: next_series,
          sunat_next_nota_credito_boleta_number: next_number
        )
      end
    end

    def save_document_from_error(document_data)
      @credit_note.sunat_documents.create!(
        sunat_uuid: document_data["uuid"] || document_data["id"],
        sunat_status: document_data["status"] || "ERROR",
        sunat_series: document_data["series"],
        sunat_number: document_data["correlative"] || document_data["number"]
      )
      @credit_note.update!(status: :error)
    rescue ActiveRecord::RecordInvalid
      # No perder el error original si falla el guardado
    end
  end
end
