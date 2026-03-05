class CreateCarriers < ActiveRecord::Migration[8.0]
  def change
    create_table :carriers do |t|
      t.references :enterprise, null: false, foreign_key: true
      t.string :ruc, null: false
      t.string :name, null: false
      t.string :status, null: false, default: "active"

      t.timestamps
    end

    add_index :carriers, [ :enterprise_id, :ruc ], unique: true
  end
end
