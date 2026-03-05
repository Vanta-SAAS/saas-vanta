module Sunat
  class CheckDispatchGuideStatusService < BaseService
    attr_reader :status_result

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

      settings = @guide.enterprise.settings
      client = ApiClient.new(api_key: settings.sunat_api_key)

      @status_result = client.get_dispatch_guide_status(@guide.sunat_uuid)
      new_status = @status_result["status"]

      @guide.update!(sunat_status: new_status) if new_status.present?

      if new_status == "ACCEPTED" && @guide.sunat_xml.blank?
        detail = client.get_dispatch_guide(@guide.sunat_uuid)
        @guide.update!(
          sunat_xml: detail["xml_signed"],
          sunat_cdr_code: detail["cdr_code"],
          sunat_cdr_description: detail["cdr_description"],
          sunat_hash: detail["hash"],
          sunat_qr_image: detail["qr_image"],
          sunat_response_data: detail
        )
      end
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
