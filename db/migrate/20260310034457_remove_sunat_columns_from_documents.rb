class RemoveSunatColumnsFromDocuments < ActiveRecord::Migration[8.1]
  def change
    sunat_columns = %i[
      sunat_uuid sunat_status sunat_document_type sunat_series sunat_number
      sunat_xml sunat_hash sunat_cdr_code sunat_cdr_description
      sunat_qr_image sunat_response_data
    ]

    %i[sales credit_notes dispatch_guides].each do |table|
      sunat_columns.each do |col|
        remove_column table, col if column_exists?(table, col)
      end
    end
  end
end
