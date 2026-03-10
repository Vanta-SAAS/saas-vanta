class CreateSunatDocuments < ActiveRecord::Migration[8.0]
  def change
    create_table :sunat_documents do |t|
      t.references :documentable, polymorphic: true, null: false
      t.boolean :voided, default: false, null: false

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

    add_index :sunat_documents, :sunat_uuid, unique: true, where: "sunat_uuid IS NOT NULL"
    add_index :sunat_documents, [ :documentable_type, :documentable_id, :voided ],
              name: "idx_sunat_docs_on_documentable_and_voided"
  end
end
