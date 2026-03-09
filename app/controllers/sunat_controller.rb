class SunatController < ApplicationController
  before_action :require_enterprise_selected
  before_action -> { require_module!(:facturacion) }

  def show
    authorize current_enterprise, :show?
    @enterprise = current_enterprise
    @settings = @enterprise.settings || @enterprise.build_settings
  end

  def register
    authorize current_enterprise, :manage?
    @enterprise = current_enterprise

    service = Sunat::RegisterEnterpriseService.new(
      enterprise: @enterprise,
      sol_user: params[:sol_user],
      sol_password: params[:sol_password]
    )
    service.call

    if service.valid?
      redirect_to sunat_path, notice: "Empresa registrada exitosamente en el servicio de facturacion."
    else
      redirect_to sunat_path, alert: service.errors_message
    end
  end

  def upload_certificate
    authorize current_enterprise, :manage?
    @enterprise = current_enterprise

    service = Sunat::UploadCertificateService.new(
      enterprise: @enterprise,
      file: params[:certificate],
      password: params[:certificate_password]
    )
    service.call

    if service.valid?
      redirect_to sunat_path, notice: "Certificado digital cargado exitosamente."
    else
      redirect_to sunat_path, alert: service.errors_message
    end
  end

  def update_settings
    authorize current_enterprise, :manage?
    @enterprise = current_enterprise
    settings = @enterprise.settings

    unless settings
      redirect_to sunat_path, alert: "Configure primero el registro SUNAT."
      return
    end

    update_params = sunat_settings_params

    if settings.sunat_api_key.present?
      client = Sunat::ApiClient.new(api_key: settings.sunat_api_key)
      api_params = {}
      api_params[:serie_factura] = update_params[:sunat_series_factura] if update_params[:sunat_series_factura].present?
      api_params[:serie_boleta] = update_params[:sunat_series_boleta] if update_params[:sunat_series_boleta].present?
      api_params[:correlativo_factura] = update_params[:sunat_next_factura_number].to_i if update_params[:sunat_next_factura_number].present?
      api_params[:correlativo_boleta] = update_params[:sunat_next_boleta_number].to_i if update_params[:sunat_next_boleta_number].present?
      api_params[:serie_grr] = update_params[:sunat_series_grr] if update_params[:sunat_series_grr].present?
      api_params[:serie_grt] = update_params[:sunat_series_grt] if update_params[:sunat_series_grt].present?
      api_params[:correlativo_grr] = update_params[:sunat_next_grr_number].to_i if update_params[:sunat_next_grr_number].present?
      api_params[:correlativo_grt] = update_params[:sunat_next_grt_number].to_i if update_params[:sunat_next_grt_number].present?
      client.update_client(api_params) if api_params.present?
    end

    settings.update!(update_params.compact_blank)
    redirect_to sunat_path, notice: "Configuracion SUNAT actualizada."
  rescue Sunat::ApiClient::Error => e
    redirect_to sunat_path, alert: e.message
  end

  def update_sol_credentials
    authorize current_enterprise, :manage?
    settings = current_enterprise.settings

    unless settings&.sunat_api_key.present?
      redirect_to sunat_path, alert: "Debe registrar la empresa primero."
      return
    end

    client = Sunat::ApiClient.new(api_key: settings.sunat_api_key)
    client.update_client(sol_user: params[:sol_user], sol_password: params[:sol_password])

    settings.update!(sunat_sol_user: params[:sol_user], sunat_sol_password: params[:sol_password])
    redirect_to sunat_path, notice: "Credenciales SOL actualizadas."
  rescue Sunat::ApiClient::Error => e
    redirect_to sunat_path, alert: e.message
  end

  def update_sunat_rest_credentials
    authorize current_enterprise, :manage?
    settings = current_enterprise.settings

    unless settings&.sunat_api_key.present?
      redirect_to sunat_path, alert: "Debe registrar la empresa primero."
      return
    end

    client = Sunat::ApiClient.new(api_key: settings.sunat_api_key)
    client.update_client(
      sunat_client_id: params[:sunat_client_id],
      sunat_client_secret: params[:sunat_client_secret]
    )

    settings.update!(
      sunat_client_id: params[:sunat_client_id],
      sunat_client_secret: params[:sunat_client_secret]
    )
    redirect_to sunat_path, notice: "Credenciales API REST de SUNAT actualizadas."
  rescue Sunat::ApiClient::Error => e
    redirect_to sunat_path, alert: e.message
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?
    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def sunat_settings_params
    params.require(:enterprise_setting).permit(
      :sunat_series_factura, :sunat_series_boleta,
      :sunat_next_factura_number, :sunat_next_boleta_number,
      :sunat_series_grr, :sunat_series_grt,
      :sunat_next_grr_number, :sunat_next_grt_number
    )
  end
end
