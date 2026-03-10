# frozen_string_literal: true

class MigrateSunatDataToSunatDocuments < ActiveRecord::Migration[8.1]
  def up
    sunat_columns = %w[
      sunat_uuid sunat_status sunat_document_type sunat_series sunat_number
      sunat_xml sunat_hash sunat_cdr_code sunat_cdr_description
      sunat_qr_image sunat_response_data
    ]

    [ Sale, CreditNote, DispatchGuide ].each do |klass|
      klass.where.not(sunat_uuid: [ nil, "" ]).find_each do |record|
        SunatDocument.create!(
          documentable: record,
          voided: false,
          **sunat_columns.each_with_object({}) { |col, hash| hash[col] = record.read_attribute(col) }
        )
      end
    end

    # Void sale documents that have an accepted credit note
    Sale.includes(:sunat_documents, credit_notes: :sunat_documents).find_each do |sale|
      sale_doc = sale.sunat_documents.where(voided: false).order(created_at: :desc).first
      next unless sale_doc

      has_accepted_cn = sale.credit_notes.any? do |cn|
        cn.sunat_documents.where(voided: false, sunat_status: "ACCEPTED").exists?
      end

      sale_doc.update!(voided: true) if has_accepted_cn
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
