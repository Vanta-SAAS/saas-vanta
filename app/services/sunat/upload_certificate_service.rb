module Sunat
  class UploadCertificateService < BaseService
    def initialize(enterprise:, file:, password:)
      super()
      @enterprise = enterprise
      @file = file
      @password = password
    end

    def call
      unless valid_required_inputs?(%i[enterprise file password],
        { enterprise: @enterprise, file: @file, password: @password })
        set_as_invalid!
        return
      end

      settings = @enterprise.settings
      unless settings&.sunat_api_key.present?
        add_error("La empresa no esta registrada en el servicio SUNAT. Registrela primero.")
        set_as_invalid!
        return
      end

      original_filename = @file.original_filename.downcase
      unless original_filename.end_with?(".pfx", ".p12")
        add_error("El archivo debe ser un certificado digital (.pfx o .p12)")
        set_as_invalid!
        return
      end

      client = ApiClient.new(api_key: settings.sunat_api_key)
      client.upload_certificate(@file.tempfile, @password)

      settings.update!(sunat_certificate_uploaded: true)
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end
  end
end
