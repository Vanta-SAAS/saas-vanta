module Documentable
  extend ActiveSupport::Concern

  included do
    belongs_to :enterprise
    belongs_to :created_by, class_name: "User"
    belongs_to :destination, class_name: "Ubigeo", optional: true

    validates :code, presence: true, uniqueness: { scope: :enterprise_id }
    validates :issue_date, presence: true
    validates :status, presence: true

    before_save :calculate_totals
  end

  private

  def calculate_totals
    active_items = items.reject(&:marked_for_destruction?)

    line_amounts = active_items.map do |item|
      PeruTax.line_amounts(
        unit_price: item.unit_price || 0,
        quantity: item.quantity || 0
      )
    end

    self.subtotal = line_amounts.sum(BigDecimal("0")) { |l| l[:line_ext] }
    self.tax = line_amounts.sum(BigDecimal("0")) { |l| l[:line_igv] }
    self.total = subtotal + tax
  end
end
