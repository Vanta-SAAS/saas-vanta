class SaleInstallment < ApplicationRecord
  belongs_to :sale

  enum :status, { pending: "pending", paid: "paid", overdue: "overdue" }

  validates :installment_number, presence: true,
    numericality: { only_integer: true, greater_than: 0 }
  validates :amount, presence: true,
    numericality: { greater_than: 0 }
  validates :due_date, presence: true
  validates :installment_number, uniqueness: { scope: :sale_id }
end
