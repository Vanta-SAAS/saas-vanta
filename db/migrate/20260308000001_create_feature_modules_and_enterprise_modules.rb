class CreateFeatureModulesAndEnterpriseModules < ActiveRecord::Migration[8.0]
  def change
    create_table :feature_modules do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :description
      t.string :icon
      t.string :kind, null: false, default: "module"
      t.references :parent, foreign_key: { to_table: :feature_modules }
      t.boolean :default_enabled, default: false, null: false
      t.integer :position, default: 0, null: false
      t.timestamps
    end

    add_index :feature_modules, :key, unique: true
    add_index :feature_modules, [:parent_id, :position]

    create_table :enterprise_modules do |t|
      t.references :enterprise, null: false, foreign_key: true
      t.references :feature_module, null: false, foreign_key: true
      t.boolean :enabled, default: true, null: false
      t.timestamps
    end

    add_index :enterprise_modules, [:enterprise_id, :feature_module_id], unique: true, name: "idx_enterprise_modules_uniq"
  end
end
