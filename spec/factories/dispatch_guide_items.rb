FactoryBot.define do
  factory :dispatch_guide_item do
    association :dispatch_guide
    description { Faker::Commerce.product_name }
    quantity { Faker::Number.between(from: 1, to: 100) }
    unit_code { "NIU" }
  end
end
