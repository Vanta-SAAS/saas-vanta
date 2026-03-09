FactoryBot.define do
  factory :customer do
    association :enterprise
    name { Faker::Company.name }
    email { Faker::Internet.email }
    tax_id_type { "ruc" }
    tax_id { "20#{Faker::Number.unique.number(digits: 9)}" }
    address { Faker::Address.full_address }
    credit_limit { 0 }
    payment_terms { 0 }

    trait :with_dni do
      tax_id_type { "dni" }
      tax_id { Faker::Number.number(digits: 8).to_s }
    end

    trait :no_document do
      tax_id_type { "no_document" }
      tax_id { nil }
    end
  end
end
