class CreateUserFields < ActiveRecord::Migration[8.0]
  def change
    create_table :user_fields do |t|
      t.references :user, null: false, foreign_key: true
      t.string :field_type, null: false
      t.text :value, null: false

      t.timestamps
    end

    add_index :user_fields, [ :user_id, :field_type ], unique: true
  end
end
