FactoryBot.define do
  factory :credit_note_item do
    association :credit_note

    description { "Producto de prueba" }
    quantity { 1 }
    unit_price { 100.00 }
    item_type { "product" }
    tax_type { "gravado" }
  end
end
