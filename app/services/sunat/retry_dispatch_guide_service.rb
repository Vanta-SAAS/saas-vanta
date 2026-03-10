module Sunat
  class RetryDispatchGuideService < BaseService
    attr_reader :retry_result

    def initialize(dispatch_guide:)
      super()
      @guide = dispatch_guide
    end

    def call
      doc = @guide.current_sunat_document

      unless doc&.sunat_uuid.present?
        add_error("Esta guia no tiene un documento emitido")
        set_as_invalid!
        return
      end

      unless doc.can_retry?
        add_error("Solo se puede reintentar documentos con estado ERROR o REJECTED")
        set_as_invalid!
        return
      end

      settings = @guide.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      @retry_result = client.retry_dispatch_guide(doc.sunat_uuid)
      new_status = @retry_result["status"]

      doc.update!(sunat_status: new_status) if new_status.present?
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
