class AddSunatCredentialsAndCreditNoteFieldsToEnterpriseSettings < ActiveRecord::Migration[8.0]
  def change
    # SUNAT REST API credentials (per-client OAuth2 for dispatch guides)
    add_column :enterprise_settings, :sunat_client_id, :string
    add_column :enterprise_settings, :sunat_client_secret, :string

    # Credit note series and correlatives (separate for facturas and boletas)
    add_column :enterprise_settings, :sunat_series_nota_credito_factura, :string
    add_column :enterprise_settings, :sunat_next_nota_credito_factura_number, :integer
    add_column :enterprise_settings, :sunat_series_nota_credito_boleta, :string
    add_column :enterprise_settings, :sunat_next_nota_credito_boleta_number, :integer
  end
end
