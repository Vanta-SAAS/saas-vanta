class AddSunatFieldsToSales < ActiveRecord::Migration[8.1]
  def change
    add_column :sales, :sunat_uuid, :string
    add_column :sales, :sunat_status, :string
    add_column :sales, :sunat_document_type, :string
    add_column :sales, :sunat_series, :string
    add_column :sales, :sunat_number, :integer

    add_index :sales, :sunat_uuid, unique: true, where: "sunat_uuid IS NOT NULL"
    add_index :sales, :sunat_status
  end
end
