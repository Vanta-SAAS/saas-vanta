module Sunat
  class CheckStatusService < BaseService
    attr_reader :status_result

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

      settings = @sale.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      @status_result = client.get_document_status(@sale.sunat_uuid)
      new_status = @status_result["status"]

      @sale.update!(sunat_status: new_status) if new_status.present?

      if new_status == "ACCEPTED" && @sale.sunat_xml.blank?
        detail = client.get_document(@sale.sunat_uuid)
        @sale.update!(
          sunat_xml: detail["xml_signed"],
          sunat_cdr_code: detail["cdr_code"],
          sunat_cdr_description: detail["cdr_description"],
          sunat_hash: detail["hash"],
          sunat_response_data: detail
        )
      end
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
