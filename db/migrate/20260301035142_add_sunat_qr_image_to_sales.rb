class AddSunatQrImageToSales < ActiveRecord::Migration[8.1]
  def change
    add_column :sales, :sunat_qr_image, :text
  end
end
