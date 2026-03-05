class CreateDispatchGuideItems < ActiveRecord::Migration[8.0]
  def change
    create_table :dispatch_guide_items do |t|
      t.references :dispatch_guide, null: false, foreign_key: true
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false
      t.string :unit_code, null: false, default: "NIU"
      t.references :product, foreign_key: true

      t.timestamps
    end
  end
end
