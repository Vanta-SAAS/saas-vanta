class CreditNoteItem < ApplicationRecord
  belongs_to :credit_note

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

  before_save :calculate_total

  private

  def calculate_total
    self.total = (quantity || 0) * (unit_price || 0)
  end
end
