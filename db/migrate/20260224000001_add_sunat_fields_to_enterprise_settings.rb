class AddSunatFieldsToEnterpriseSettings < ActiveRecord::Migration[8.1]
  def change
    add_reference :enterprises, :ubigeo, foreign_key: { to_table: :ubigeos }, null: true

    add_column :enterprise_settings, :sunat_api_key, :string
    add_column :enterprise_settings, :sunat_certificate_uploaded, :boolean, default: false, null: false
    add_column :enterprise_settings, :sunat_series_factura, :string, default: "F001"
    add_column :enterprise_settings, :sunat_series_boleta, :string, default: "B001"
    add_column :enterprise_settings, :sunat_sol_user, :string
    add_column :enterprise_settings, :sunat_sol_password, :string
  end
end
