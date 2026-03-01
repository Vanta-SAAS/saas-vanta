module Sunat
  class RetryDocumentService < BaseService
    attr_reader :retry_result

    def initialize(sale:)
      super()
      @sale = sale
    end

    def call
      unless @sale.sunat_uuid.present?
        add_error("Esta venta no tiene un comprobante emitido")
        set_as_invalid!
        return
      end

      unless @sale.sunat_status.in?(%w[ERROR REJECTED])
        add_error("Solo se puede reintentar documentos con estado ERROR o REJECTED")
        set_as_invalid!
        return
      end

      settings = @sale.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      @retry_result = client.retry_document(@sale.sunat_uuid)
      new_status = @retry_result["status"]

      @sale.update!(sunat_status: new_status) if new_status.present?
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
