FactoryBot.define do
  factory :carrier do
    association :enterprise
    ruc { "20#{Faker::Number.unique.number(digits: 9)}" }
    name { Faker::Company.name }
    status { "active" }
  end
end
