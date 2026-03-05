class AddColorFieldsToEnterpriseSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :enterprise_settings, :primary_color, :string
    add_column :enterprise_settings, :secondary_color, :string
  end
end
