FactoryBot.define do
  factory :sale_installment do
    association :sale
    sequence(:installment_number) { |n| n }
    amount { 100.00 }
    due_date { 30.days.from_now.to_date }
    status { "pending" }
  end
end
