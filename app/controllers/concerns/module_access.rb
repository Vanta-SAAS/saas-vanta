module ModuleAccess
  extend ActiveSupport::Concern

  private

  def require_module!(mod)
    return if current_enterprise.module_enabled?(mod)

    redirect_to root_path, alert: "Este módulo no está habilitado para tu empresa."
  end
end
