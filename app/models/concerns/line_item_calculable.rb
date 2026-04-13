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

  # Montos de linea alineados con el microservicio de facturacion:
  # base_unit sin redondear, line_ext y line_igv con redondeo a 2 decimales.
  def line_amounts
    PeruTax.line_amounts(unit_price: unit_price, quantity: quantity)
  end

  def line_ext
    line_amounts[:line_ext]
  end

  def line_igv
    line_amounts[:line_igv]
  end

  private

  def calculate_total
    self.total = line_amounts[:line_total]
  end
end
