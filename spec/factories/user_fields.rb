FactoryBot.define do
  factory :user_field do
    association :user
    field_type { "driving_license_number" }
    value { "Q#{Faker::Number.number(digits: 8)}" }

    trait :doc_number do
      field_type { "doc_number" }
      value { Faker::Number.number(digits: 8).to_s }
    end

    trait :doc_type do
      field_type { "doc_type" }
      value { "dni" }
    end
  end
end
