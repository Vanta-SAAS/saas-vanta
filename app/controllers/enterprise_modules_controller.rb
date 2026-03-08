class EnterpriseModulesController < ApplicationController
  before_action :require_enterprise_selection

  def show
    @enterprise = current_enterprise
    authorize @enterprise, :edit?
    @root_modules = FeatureModule.roots.ordered.includes(:children)
    @module_states = @enterprise.enterprise_modules
      .joins(:feature_module)
      .pluck("feature_modules.key", "enterprise_modules.enabled")
      .to_h
  end

  def update
    @enterprise = current_enterprise
    authorize @enterprise, :edit?

    modules_params.each do |key, enabled|
      fm = FeatureModule.find_by(key: key)
      next unless fm

      em = @enterprise.enterprise_modules.find_or_initialize_by(feature_module: fm)
      em.update!(enabled: enabled == "1")
    end

    @enterprise.instance_variable_set(:@module_states, nil)

    redirect_to enterprise_modules_configuration_path(@enterprise), notice: "Configuración de módulos actualizada."
  end

  private

  def modules_params
    params.permit(modules: {})[:modules] || {}
  end
end
