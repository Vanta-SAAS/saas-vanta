class Product < ApplicationRecord
  # Asociations
  belongs_to :enterprise
  belongs_to :provider, optional: true
  has_many :purchase_order_items, dependent: :restrict_with_error
  has_many :customer_quote_items, dependent: :restrict_with_error
  has_many :sale_items, dependent: :restrict_with_error

  # Normalizations
  normalizes :sku, with: ->(value) { value.strip.presence }

  # Defaults
  before_validation :set_default_unit

  validates :units_per_package, numericality: { greater_than: 0 }, allow_nil: true

  # Validations
  validates :name, presence: true
  validates :buy_price, presence: true, numericality: { greater_than_or_equal_to: 0 }, if: :purchased?
  validates :sell_cash_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :sell_credit_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validate :validate_stock, unless: :service?
  validate :provider_presence_based_on_source, unless: :service?

  # Enums
  enum :unit, {
    kg: "kg",
    g: "g",
    lt: "lt",
    ml: "ml",
    un: "un",
    cl: "cl"
  }

  enum :status, {
    active: "active",
    inactive: "inactive",
    discontinued: "discontinued"
  }

  enum :source_type, {
    purchased: "purchased",
    manufactured: "manufactured",
    other: "other"
  }

  enum :product_type, {
    good: "good",
    service: "service"
  }

  scope :goods, -> { where(product_type: :good) }
  scope :services, -> { where(product_type: :service) }

  def capacity_label
    return nil unless capacity.present? && capacity > 0
    "#{capacity.to_s.gsub(/\.?0+$/, '')}#{unit}"
  end

  def combobox_display
    parts = [ name ]
    parts << capacity_label if capacity_label
    parts << "(#{sku})" if sku.present?
    parts.join(" ")
  end

  private

  def validate_stock
    return unless stock.present?
    errors_msg = "El stock debe ser un número entero no negativo"

    raw_value = stock_before_type_cast
    unless raw_value.is_a?(Integer) || (raw_value.is_a?(String) && raw_value.match?(/\A\d+\z/))
      errors.add(:base, errors_msg)
      return
    end

    if stock.negative?
      errors.add(:base, errors_msg)
    end
  end

  def provider_presence_based_on_source
    return unless source_type == "purchased"

    errors.add(:base, "Proveedor es obligatorio para productos comprados") if provider.nil?
  end

  def set_default_unit
    self.unit ||= "un"
  end
end
