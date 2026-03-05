FactoryBot.define do
  factory :vehicle do
    association :enterprise
    plate { "#{('A'..'Z').to_a.sample(3).join}-#{Faker::Number.number(digits: 3)}" }
    brand { Faker::Vehicle.make }
    model { Faker::Vehicle.model }
    status { "active" }
  end
end
