class AddSunatRestCredentialsToEnterpriseSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :enterprise_settings, :sunat_client_id, :string
    add_column :enterprise_settings, :sunat_client_secret, :string
  end
end
