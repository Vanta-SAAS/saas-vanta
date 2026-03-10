FactoryBot.define do
  factory :dispatch_guide do
    association :enterprise
    association :created_by, factory: :user
    code { "GR-#{Faker::Number.unique.number(digits: 4)}-#{Date.current.year}" }
    guide_type { "grr" }
    status { "draft" }
    issue_date { Date.current }
    transfer_date { Date.current + 1.day }
    transfer_reason { "venta" }
    transport_modality { "private" }
    gross_weight { Faker::Number.decimal(l_digits: 2, r_digits: 2) }
    departure_address { Faker::Address.full_address }
    arrival_address { Faker::Address.full_address }
    recipient_doc_type { "ruc" }
    recipient_doc_number { "20#{Faker::Number.number(digits: 9)}" }
    recipient_name { Faker::Company.name }

    association :vehicle
    association :driver, factory: :user

    trait :grt do
      guide_type { "grt" }
      recipient_doc_type { nil }
      recipient_doc_number { nil }
      recipient_name { nil }
      shipper_doc_type { "ruc" }
      shipper_doc_number { "20#{Faker::Number.number(digits: 9)}" }
      shipper_name { Faker::Company.name }
    end

    trait :public_transport do
      transport_modality { "public" }
      vehicle { nil }
      driver { nil }
      association :carrier
    end

    trait :emitted do
      status { "emitted" }

      after(:create) do |guide|
        create(:sunat_document,
          documentable: guide,
          sunat_uuid: SecureRandom.uuid,
          sunat_status: "ACCEPTED",
          sunat_document_type: "09",
          sunat_series: "T001",
          sunat_number: Faker::Number.number(digits: 4)
        )
      end
    end
  end
end
