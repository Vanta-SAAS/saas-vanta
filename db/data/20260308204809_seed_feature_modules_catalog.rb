# frozen_string_literal: true

class SeedFeatureModulesCatalog < ActiveRecord::Migration[8.1]
  def up
    modules = [
      { key: "ventas", name: "Ventas", description: "Gestión de ventas, cotizaciones y documentos comerciales", icon: "shopping-cart", kind: "module", default_enabled: true, position: 1 },
      { key: "compras", name: "Compras", description: "Órdenes de compra y gestión de proveedores", icon: "package", kind: "module", default_enabled: false, position: 2 },
      { key: "facturacion", name: "Facturación Electrónica", description: "Emisión de comprobantes electrónicos vía SUNAT", icon: "receipt", kind: "module", default_enabled: false, position: 3 },
      { key: "despacho", name: "Despacho", description: "Logística, vehículos y transportistas", icon: "truck", kind: "module", default_enabled: false, position: 4 }
    ]

    now = Time.current
    modules.each do |mod|
      execute <<-SQL.squish
        INSERT INTO feature_modules (key, name, description, icon, kind, default_enabled, position, created_at, updated_at)
        VALUES (#{quote(mod[:key])}, #{quote(mod[:name])}, #{quote(mod[:description])}, #{quote(mod[:icon])}, #{quote(mod[:kind])}, #{mod[:default_enabled]}, #{mod[:position]}, #{quote(now)}, #{quote(now)})
        ON CONFLICT (key) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, icon = EXCLUDED.icon, default_enabled = EXCLUDED.default_enabled, position = EXCLUDED.position, updated_at = EXCLUDED.updated_at
      SQL
    end

    children = [
      { parent: "ventas", key: "ventas.cotizaciones", name: "Cotizaciones", description: "Crear y gestionar cotizaciones para clientes", default_enabled: true, position: 1 },
      { parent: "ventas", key: "ventas.productos_tangibles", name: "Productos tangibles", description: "Venta de productos físicos", default_enabled: true, position: 2 },
      { parent: "ventas", key: "ventas.servicios", name: "Servicios", description: "Venta de servicios", default_enabled: false, position: 3 },
      { parent: "ventas", key: "ventas.stock_kardex", name: "Gestión de stock y kardex", description: "Control de inventario y movimientos de stock", default_enabled: false, position: 4, badge: "Próximamente" },
      { parent: "ventas", key: "ventas.letras_cambio", name: "Letras de cambio", description: "Gestión de letras de cambio para cobros", default_enabled: false, position: 5, badge: "Próximamente" },
      { parent: "ventas", key: "ventas.credito_clientes", name: "Crédito a clientes", description: "Habilitar líneas de crédito y condiciones de pago", default_enabled: false, position: 6, badge: "Próximamente" },
      { parent: "compras", key: "compras.dropshipping", name: "Dropshipping", description: "Generar órdenes de compra automáticamente desde ventas", default_enabled: false, position: 1 },
      { parent: "facturacion", key: "facturacion.facturas", name: "Facturas y Notas de crédito", description: "Emisión de facturas electrónicas y sus notas de crédito", default_enabled: true, position: 1 },
      { parent: "facturacion", key: "facturacion.boletas", name: "Boletas", description: "Emisión de boletas de venta electrónicas", default_enabled: true, position: 2, badge: "Próximamente" },
      { parent: "facturacion", key: "facturacion.guias_remision", name: "Guías de remisión electrónicas", description: "Emisión de guías de remisión vía SUNAT", default_enabled: false, position: 3 },
      { parent: "despacho", key: "despacho.vehiculos", name: "Vehículos Propios", description: "Registro y gestión de vehículos de transporte", default_enabled: false, position: 1 },
      { parent: "despacho", key: "despacho.transportistas", name: "Transportistas", description: "Registro y gestión de empresas transportistas", default_enabled: true, position: 2 }
    ]

    children.each do |child|
      badge = child[:badge] ? quote(child[:badge]) : "NULL"
      execute <<-SQL.squish
        INSERT INTO feature_modules (key, name, description, kind, default_enabled, position, badge, parent_id, created_at, updated_at)
        VALUES (
          #{quote(child[:key])}, #{quote(child[:name])}, #{quote(child[:description])}, 'option', #{child[:default_enabled]}, #{child[:position]}, #{badge},
          (SELECT id FROM feature_modules WHERE key = #{quote(child[:parent])}),
          #{quote(now)}, #{quote(now)}
        )
        ON CONFLICT (key) DO UPDATE SET name = EXCLUDED.name, description = EXCLUDED.description, default_enabled = EXCLUDED.default_enabled, position = EXCLUDED.position, badge = EXCLUDED.badge, parent_id = EXCLUDED.parent_id, updated_at = EXCLUDED.updated_at
      SQL
    end

    # Initialize enterprise_modules for all existing enterprises
    execute <<-SQL.squish
      INSERT INTO enterprise_modules (enterprise_id, feature_module_id, enabled, created_at, updated_at)
      SELECT e.id, fm.id, fm.default_enabled, #{quote(now)}, #{quote(now)}
      FROM enterprises e
      CROSS JOIN feature_modules fm
      WHERE NOT EXISTS (
        SELECT 1 FROM enterprise_modules em
        WHERE em.enterprise_id = e.id AND em.feature_module_id = fm.id
      )
    SQL
  end

  def down
    FeatureModule.destroy_all
  end

  private

  def quote(value)
    ActiveRecord::Base.connection.quote(value)
  end
end
