module Sunat
  class RegisterEnterpriseService < BaseService
    def initialize(enterprise:, sol_user:, sol_password:)
      super()
      @enterprise = enterprise
      @sol_user = sol_user
      @sol_password = sol_password
    end

    def call
      unless valid_required_inputs?(%i[enterprise sol_user sol_password],
        { enterprise: @enterprise, sol_user: @sol_user, sol_password: @sol_password })
        set_as_invalid!
        return
      end

      unless @enterprise.formal?
        add_error("Solo empresas formales (con RUC) pueden emitir comprobantes electronicos")
        set_as_invalid!
        return
      end

      settings = @enterprise.settings || @enterprise.build_settings
      settings.sunat_sol_user = @sol_user
      settings.sunat_sol_password = @sol_password
      settings.save!

      client = ApiClient.new
      result = client.register_client(@enterprise)

      api_key = result["api_key"]
      unless api_key.present?
        add_error("No se recibio el API key del servicio")
        set_as_invalid!
        return
      end

      settings.update!(sunat_api_key: api_key)
      @api_key = api_key
    rescue Sunat::ApiClient::Error => e
      add_error(e.message)
      set_as_invalid!
    end

    def api_key
      @api_key
    end
  end
end
