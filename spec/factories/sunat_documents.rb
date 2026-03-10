FactoryBot.define do
  factory :sunat_document do
    association :documentable, factory: :sale
    sunat_uuid { SecureRandom.uuid }
    sunat_status { "ACCEPTED" }
    sunat_document_type { "01" }
    sunat_series { "F001" }
    sunat_number { Faker::Number.number(digits: 4) }
    voided { false }

    trait :accepted do
      sunat_status { "ACCEPTED" }
      sunat_xml { "<xml>signed</xml>" }
      sunat_cdr_code { "0" }
      sunat_cdr_description { "Documento aceptado" }
      sunat_hash { "abc123" }
    end

    trait :error do
      sunat_status { "ERROR" }
    end

    trait :rejected do
      sunat_status { "REJECTED" }
    end

    trait :voided do
      voided { true }
    end
  end
end
