class AddSunatDocumentDataToSales < ActiveRecord::Migration[8.0]
  def change
    add_column :sales, :sunat_xml, :text
    add_column :sales, :sunat_cdr_code, :string
    add_column :sales, :sunat_cdr_description, :text
    add_column :sales, :sunat_hash, :string
    add_column :sales, :sunat_response_data, :jsonb
  end
end
