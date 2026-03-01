class AddSunatNextDocumentFieldsToEnterpriseSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :enterprise_settings, :sunat_next_factura_series, :string
    add_column :enterprise_settings, :sunat_next_factura_number, :integer
    add_column :enterprise_settings, :sunat_next_boleta_series, :string
    add_column :enterprise_settings, :sunat_next_boleta_number, :integer
  end
end
