module LineItemCalculable
  extend ActiveSupport::Concern

  included do
    belongs_to :product

    validates :quantity, presence: true, numericality: { greater_than: 0 }
    validates :unit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }

    before_save :calculate_total
  end

  def unit_label
    product.capacity_label || product.unit.upcase
  end

  private

  def calculate_total
    self.total = (quantity || 0) * (unit_price || 0)
  end
end
