class AddDispatchGuideSeriesToEnterpriseSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :enterprise_settings, :sunat_series_grr, :string, default: "T001"
    add_column :enterprise_settings, :sunat_series_grt, :string, default: "V001"
    add_column :enterprise_settings, :sunat_next_grr_number, :integer
    add_column :enterprise_settings, :sunat_next_grr_series, :string
    add_column :enterprise_settings, :sunat_next_grt_number, :integer
    add_column :enterprise_settings, :sunat_next_grt_series, :string
  end
end
