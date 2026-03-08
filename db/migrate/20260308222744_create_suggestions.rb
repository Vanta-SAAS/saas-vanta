class CreateSuggestions < ActiveRecord::Migration[8.1]
  def change
    create_table :suggestions do |t|
      t.references :enterprise, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.text :body, null: false
      t.string :contact_email
      t.string :contact_phone
      t.boolean :wants_contact, default: false

      t.timestamps
    end
  end
end
