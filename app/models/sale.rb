class Sale < ApplicationRecord
  include Documentable

  belongs_to :customer
  belongs_to :seller, class_name: "User"
  belongs_to :sourceable, polymorphic: true, optional: true

  has_many :items, class_name: "SaleItem", dependent: :destroy
  has_many :purchase_orders, as: :sourceable
  has_many :dispatch_guides, as: :sourceable
  accepts_nested_attributes_for :items, allow_destroy: true, reject_if: :all_blank

  enum :status, { pending: "pending", confirmed: "confirmed", cancelled: "cancelled" }

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
    confirmed? && purchase_orders.empty? && enterprise.settings&.dropshipping_enabled?
  end

  def can_emit_document?
    confirmed? && sunat_uuid.blank? && enterprise.settings&.sunat_api_key.present? && enterprise.settings&.sunat_certificate_uploaded?
  end

  def can_retry_document?
    sunat_uuid.present? && sunat_status.in?(%w[ERROR REJECTED])
  end

  def sunat_status_badge_class
    case sunat_status
    when "ACCEPTED" then "badge-success"
    when "REJECTED" then "badge-destructive"
    when "ERROR" then "badge-destructive"
    when "SIGNED", "CREATED" then "badge-secondary"
    else "badge-secondary"
    end
  end

  def sunat_formatted_number
    return nil unless sunat_series.present? && sunat_number.present?

    "#{sunat_series}-#{sunat_number.to_s.rjust(8, '0')}"
  end

  def sunat_document_type_label
    case sunat_document_type
    when "01" then "Factura"
    when "03" then "Boleta"
    else sunat_document_type
    end
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
