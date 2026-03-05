class CreateDispatchGuides < ActiveRecord::Migration[8.0]
  def change
    create_table :dispatch_guides do |t|
      t.string :code, null: false
      t.references :enterprise, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :guide_type, null: false
      t.string :status, null: false, default: "draft"
      t.date :issue_date, null: false
      t.date :transfer_date, null: false
      t.string :transfer_reason, null: false
      t.string :transport_modality, null: false
      t.decimal :gross_weight, precision: 10, scale: 2
      t.text :notes

      # Origen/destino del traslado
      t.references :departure_ubigeo, foreign_key: { to_table: :ubigeos }
      t.string :departure_address
      t.references :arrival_ubigeo, foreign_key: { to_table: :ubigeos }
      t.string :arrival_address

      # Destinatario
      t.string :recipient_doc_type
      t.string :recipient_doc_number
      t.string :recipient_name

      # Transporte privado
      t.references :vehicle, foreign_key: true
      t.references :driver, foreign_key: { to_table: :users }

      # Transporte publico (transportista tercero)
      t.references :carrier, foreign_key: true
      t.string :carrier_ruc
      t.string :carrier_name

      # Para GRT: datos del remitente
      t.string :shipper_doc_type
      t.string :shipper_doc_number
      t.string :shipper_name

      # Vinculo opcional con venta u otro documento
      t.references :sourceable, polymorphic: true

      # Campos SUNAT
      t.string :sunat_uuid
      t.string :sunat_status
      t.string :sunat_document_type
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

    add_index :dispatch_guides, [ :enterprise_id, :code ], unique: true
    add_index :dispatch_guides, :sunat_uuid, unique: true, where: "sunat_uuid IS NOT NULL"
    add_index :dispatch_guides, :status
  end
end
