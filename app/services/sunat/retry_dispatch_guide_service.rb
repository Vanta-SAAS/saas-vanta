module Sunat
  class RetryDispatchGuideService < BaseService
    attr_reader :retry_result

    def initialize(dispatch_guide:)
      super()
      @guide = dispatch_guide
    end

    def call
      unless @guide.sunat_uuid.present?
        add_error("Esta guia no tiene un documento emitido")
        set_as_invalid!
        return
      end

      unless @guide.sunat_status.in?(%w[ERROR REJECTED])
        add_error("Solo se puede reintentar documentos con estado ERROR o REJECTED")
        set_as_invalid!
        return
      end

      settings = @guide.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      @retry_result = client.retry_dispatch_guide(@guide.sunat_uuid)
      new_status = @retry_result["status"]

      @guide.update!(sunat_status: new_status) if new_status.present?
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
