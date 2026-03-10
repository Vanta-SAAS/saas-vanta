class CreateCreditNotes < ActiveRecord::Migration[8.0]
  def change
    create_table :credit_notes do |t|
      t.references :enterprise, null: false, foreign_key: true
      t.references :sale, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }

      t.string :code, null: false
      t.string :reason_code, null: false
      t.text :description, null: false
      t.string :status, null: false, default: "pending"

      # Totals
      t.decimal :subtotal, precision: 12, scale: 2, default: 0
      t.decimal :tax, precision: 12, scale: 2, default: 0
      t.decimal :total, precision: 12, scale: 2, default: 0

      # SUNAT fields
      t.string :sunat_uuid
      t.string :sunat_status
      t.string :sunat_document_type, default: "07"
      t.string :sunat_series
      t.integer :sunat_number
      t.text :sunat_xml
      t.string :sunat_cdr_code
      t.text :sunat_cdr_description
      t.string :sunat_hash
      t.text :sunat_qr_image
      t.jsonb :sunat_response_data

      t.timestamps
    end

    add_index :credit_notes, [ :enterprise_id, :code ], unique: true

    create_table :credit_note_items do |t|
      t.references :credit_note, null: false, foreign_key: true

      t.string :description, null: false
      t.decimal :quantity, precision: 12, scale: 2, null: false
      t.decimal :unit_price, precision: 12, scale: 2, null: false
      t.decimal :total, precision: 12, scale: 2, default: 0
      t.string :item_type, default: "product"
      t.string :tax_type, default: "gravado"

      t.timestamps
    end
  end
end
