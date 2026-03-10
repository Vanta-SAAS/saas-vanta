FactoryBot.define do
  factory :sale do
    association :enterprise
    association :customer
    association :seller, factory: :user
    association :created_by, factory: :user
    code { "VTA-#{Faker::Number.unique.number(digits: 4)}-#{Date.current.year}" }
    issue_date { Date.current }
    status { "pending" }
    payment_condition { "cash" }
    total { 0 }
    subtotal { 0 }
    tax { 0 }

    trait :confirmed do
      status { "confirmed" }
    end

    trait :credit do
      payment_condition { "credit" }
    end
  end
end
