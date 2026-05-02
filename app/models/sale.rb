class Sale < ApplicationRecord
  include Documentable
  include SunatDocumentable

  belongs_to :customer
  belongs_to :seller, class_name: "User"
  belongs_to :sourceable, polymorphic: true, optional: true

  has_many :items, class_name: "SaleItem", dependent: :destroy
  has_many :installments, class_name: "SaleInstallment", dependent: :destroy
  has_many :purchase_orders, as: :sourceable
  has_many :dispatch_guides, as: :sourceable
  has_many :credit_notes, dependent: :destroy
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank
  accepts_nested_attributes_for :installments, allow_destroy: true, reject_if: :all_blank

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" }
  enum :payment_condition, { cash: "cash", credit: "credit" }

  validates :payment_condition, presence: true
  validate :validate_installments_for_credit
  validate :validate_no_installments_for_cash
  validate :validate_credit_limit, if: -> { credit? && customer.present? }

  def self.generate_next_code(enterprise)
    current_year = Date.current.year
    last_record = enterprise.sales
      .where("code LIKE ?", "VTA-%-#{current_year}")
      .order(created_at: :desc)
      .first
    last_number = last_record&.code&.split("-")&.second.to_i || 0
    "VTA-#{(last_number + 1).to_s.rjust(4, '0')}-#{current_year}"
  end

  def can_edit?
    pending?
  end

  def can_confirm?
    pending? && items.any?
  end

  def can_cancel?
    pending?
  end

  def can_generate_purchase_orders?
    confirmed? && purchase_orders.empty? && enterprise.module_enabled?("compras.dropshipping")
  end

  def can_emit_document?
    doc = current_sunat_document
    confirmed? &&
      (doc.nil? || doc.can_retry?) &&
      enterprise.settings&.sunat_api_key.present? &&
      enterprise.settings&.sunat_certificate_uploaded?
  end

  def can_emit_credit_note?
    doc = current_sunat_document
    doc.present? && doc.accepted? && !doc.voided?
  end

  def has_accepted_credit_note?
    credit_notes.where(status: :emitted).exists?
  end

  def can_create_dispatch_guide?
    confirmed? && has_goods? && !dispatch_guides.exists? &&
      enterprise.settings&.sunat_api_key.present? &&
      enterprise.settings&.sunat_certificate_uploaded?
  end

  def has_goods?
    items.joins(:product).where(products: { product_type: :good }).exists?
  end

  def confirm!
    return false unless can_confirm?

    transaction do
      update!(status: :confirmed)
      update_product_stock! if enterprise.use_stock?
    end

    true
  end

  def cancel!
    return false unless can_cancel?

    update!(status: :cancelled)
  end

  def status_badge_class
    case status
    when "pending" then "badge-secondary"
    when "confirmed" then "badge-success"
    when "cancelled" then "badge-destructive"
    else "badge-secondary"
    end
  end

  def status_label
    { "pending" => "Pendiente", "confirmed" => "Confirmada", "cancelled" => "Cancelada" }[status] || status.humanize
  end

  def generate_purchase_orders!(created_by:)
    return false unless can_generate_purchase_orders?

    items_without_provider = items.includes(product: :provider).select { |item| item.product.provider.nil? }
    if items_without_provider.any?
      names = items_without_provider.map { |i| i.product.name }.join(", ")
      errors.add(:base, "Los siguientes productos no tienen proveedor asignado: #{names}")
      return false
    end

    items_by_provider = items.includes(product: :provider).group_by { |item| item.product.provider }
    historical_data_recoverer = PurchaseOrders::HistoricalDataRecoverer.new(enterprise: enterprise, customer_id: customer.id)
    historical_data_recoverer.call
    last_order_data = historical_data_recoverer.last_order_data

    transaction do
      items_by_provider.each do |provider, sale_items|
        po = enterprise.purchase_orders.create!(
          code: PurchaseOrder.generate_next_code(enterprise),
          provider: provider,
          sourceable: self,
          delivery_address: customer.ubigeo&.full_path,
          issue_date: Date.current,
          status: :draft,
          created_by: created_by,
          notes: last_order_data[:last_notes]
        )

        sale_items.each do |item|
          po.items.create!(
            product: item.product,
            quantity: item.quantity,
            unit_price: item.product.buy_price
          )
        end

        po.save!
      end
    end

    true
  end

  private

  def validate_installments_for_credit
    return unless credit?

    cuotas = installments.reject(&:marked_for_destruction?)
    if cuotas.empty?
      errors.add(:base, "Las ventas a crédito requieren al menos una cuota")
    elsif total.present? && total.positive? && cuotas.sum(&:amount) != total
      errors.add(:base, "Las cuotas deben sumar el total del documento (S/ #{total})")
    end
  end

  def validate_no_installments_for_cash
    return unless cash?

    if installments.reject(&:marked_for_destruction?).any?
      errors.add(:base, "No se permiten cuotas en ventas al contado")
    end
  end

  def validate_credit_limit
    return unless customer.credit_limit.positive?

    available = customer.available_credit
    # Si estamos editando, sumar las cuotas anteriores de esta venta
    if persisted?
      own_pending = installments.where(status: "pending").sum(:amount)
      available += own_pending
    end

    if total.present? && total > available
      errors.add(:base, "El monto excede el crédito disponible del cliente (S/ #{available.round(2)})")
    end
  end

  def update_product_stock!
    items.includes(:product).find_each do |item|
      next if item.product.service?

      product = item.product
      current_stock = product.stock || 0
      new_stock = current_stock - item.quantity
      product.update!(stock: [ new_stock, 0 ].max)
    end
  end
end
