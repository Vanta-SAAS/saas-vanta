class CreateVehicles < ActiveRecord::Migration[8.0]
  def change
    create_table :vehicles do |t|
      t.references :enterprise, null: false, foreign_key: true
      t.string :plate, null: false
      t.string :brand
      t.string :model
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :vehicles, [ :enterprise_id, :plate ], unique: true
  end
end
