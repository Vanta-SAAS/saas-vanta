FactoryBot.define do
  factory :sale_item do
    association :sale
    association :product
    quantity { Faker::Number.between(from: 1, to: 10) }
    unit_price { Faker::Commerce.price(range: 10.0..100.0) }
  end
end
