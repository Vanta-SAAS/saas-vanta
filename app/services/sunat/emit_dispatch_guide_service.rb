module Sunat
  class EmitDispatchGuideService < BaseService
    attr_reader :sunat_result

    def initialize(dispatch_guide:)
      super()
      @guide = dispatch_guide
    end

    def call
      validate_prerequisites!
      return unless valid?

      settings = @guide.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      doc = @guide.current_sunat_document

      @sunat_result = if doc&.can_retry?
        client.retry_dispatch_guide(doc.sunat_uuid)
      elsif @guide.grr?
        client.create_dispatch_guide_remitente(@guide)
      else
        client.create_dispatch_guide_transportista(@guide)
      end

      sunat_status = @sunat_result["status"] || "CREATED"

      # Create or update the SunatDocument record
      sunat_doc = doc&.can_retry? ? doc : @guide.sunat_documents.build
      sunat_doc.update!(
        sunat_uuid: @sunat_result["uuid"] || @sunat_result["id"],
        sunat_status: sunat_status,
        sunat_document_type: @guide.grr? ? "09" : "31",
        sunat_series: @sunat_result["series"],
        sunat_number: @sunat_result["correlative"] || @sunat_result["number"],
        sunat_xml: @sunat_result["xml_signed"],
        sunat_cdr_code: @sunat_result["cdr_code"],
        sunat_cdr_description: @sunat_result["cdr_description"],
        sunat_hash: @sunat_result["hash"],
        sunat_qr_image: @sunat_result["qr_image"],
        sunat_response_data: @sunat_result
      )

      @guide.update!(status: sunat_status == "REJECTED" ? :draft : :emitted)

      if sunat_status == "REJECTED"
        description = @sunat_result["cdr_description"] || "Documento rechazado por SUNAT"
        add_error("SUNAT rechazo el documento: #{description}")
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
      unless @guide.draft?
        add_error("La guia debe estar en borrador para emitir")
        set_as_invalid!
        return
      end

      doc = @guide.current_sunat_document
      if doc.present? && !doc.can_retry?
        add_error("Esta guia ya tiene un documento emitido")
        set_as_invalid!
        return
      end

      settings = @guide.enterprise.settings
      unless settings&.sunat_api_key.present?
        add_error("La empresa no esta registrada en el servicio SUNAT")
        set_as_invalid!
        return
      end

      unless settings.sunat_certificate_uploaded?
        add_error("La empresa no tiene certificado digital cargado")
        set_as_invalid!
        return
      end

      unless @guide.items.any?
        add_error("La guia debe tener al menos un item")
        set_as_invalid!
      end
    end

    def save_document_from_error(document_data)
      @guide.sunat_documents.create!(
        sunat_uuid: document_data["uuid"] || document_data["id"],
        sunat_status: document_data["status"] || "ERROR",
        sunat_document_type: @guide.grr? ? "09" : "31",
        sunat_series: document_data["series"],
        sunat_number: document_data["correlative"] || document_data["number"]
      )
    rescue ActiveRecord::RecordInvalid
      # No perder el error original si falla el guardado
    end

    def save_next_document_info!
      next_series = @sunat_result["next_document_series"]
      next_number = @sunat_result["next_document_number"]
      return unless next_series.present? || next_number.present?

      settings = @guide.enterprise.settings
      if @guide.grr?
        settings.update!(
          sunat_next_grr_series: next_series,
          sunat_next_grr_number: next_number
        )
      else
        settings.update!(
          sunat_next_grt_series: next_series,
          sunat_next_grt_number: next_number
        )
      end
    end
  end
end
