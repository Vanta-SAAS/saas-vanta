class AddSunatDocumentIdToCreditNotes < ActiveRecord::Migration[8.0]
  def change
    add_reference :credit_notes,
                  :referenced_sunat_document,
                  null: true,
                  foreign_key: { to_table: :sunat_documents }
  end
end
