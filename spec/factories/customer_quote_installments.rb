FactoryBot.define do
  factory :customer_quote_installment do
    association :customer_quote
    sequence(:installment_number) { |n| n }
    amount { 100.00 }
    due_date { 30.days.from_now.to_date }
  end
end
