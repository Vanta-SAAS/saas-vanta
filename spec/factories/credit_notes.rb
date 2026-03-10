FactoryBot.define do
  factory :credit_note do
    association :enterprise
    association :sale
    association :created_by, factory: :user

    code { "NC-#{rand(1000..9999)}-#{Date.current.year}" }
    reason_code { "anulacion_de_la_operacion" }
    description { "Anulacion de la venta" }
    status { "pending" }
  end
end
