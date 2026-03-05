class EnhanceProductsForServicesAndCapacity < ActiveRecord::Migration[8.1]
  def change
    add_column :products, :product_type, :string, default: "good", null: false
    add_column :products, :capacity, :decimal
    change_column_default :products, :buy_price, from: nil, to: 0
    change_column_null :products, :buy_price, true
  end
end
