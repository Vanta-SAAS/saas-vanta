# frozen_string_literal: true

class UpdateClientCreditSoon < ActiveRecord::Migration[8.1]
  def up
    child_module.update(badge: nil)
  end

  def down
    child_module.update(badge: 'Próximamente')
  end

  private

  def child_module
    @child_module ||= FeatureModule.find_by(key: "ventas.credito_clientes")
  end
end
