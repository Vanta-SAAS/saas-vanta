class CustomerQuoteInstallment < ApplicationRecord
  belongs_to :customer_quote

  validates :installment_number, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :amount, presence: true,
    numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :installment_number, uniqueness: { scope: :customer_quote_id }
end
