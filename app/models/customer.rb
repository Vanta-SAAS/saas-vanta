class Customer < ApplicationRecord
  # Associations
  belongs_to :enterprise
  belongs_to :ubigeo, optional: true
  has_many :customer_quotes, dependent: :restrict_with_error
  has_many :sales, dependent: :restrict_with_error

  # Validations
  validates :name, presence: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_blank: true
  validate :validate_phone_number
  validate :validate_tax_id
  validates :credit_limit, numericality: { greater_than_or_equal_to: 0 }
  validates :payment_terms, numericality: { greater_than_or_equal_to: 0, only_integer: true }

  # Enums
  enum :tax_id_type, {
    ruc: "ruc",
    dni: "dni",
    no_document: "no_document"
  }

  def combobox_display
    tax_id.present? ? "#{name} (#{tax_id})" : name
  end

  def outstanding_balance
    sales.where(payment_condition: "credit", status: %w[pending confirmed])
         .joins(:installments)
         .where(sale_installments: { status: "pending" })
         .sum("sale_installments.amount")
  end

  def available_credit
    credit_limit - outstanding_balance
  end

  private

  def validate_phone_number
    Peru::PhoneValidator.new(attributes: [ :phone_number ], allow_blank: true).validate_each(self, :phone_number, phone_number)
  end

  def validate_tax_id
    return if no_document?

    if tax_id.blank?
      errors.add(:base, "DNI o RUC es requerido")
      return
    end

    if ruc?
      Peru::TaxIdValidator.new(attributes: [ :tax_id ]).validate_each(self, :tax_id, tax_id)
    elsif dni?
      Peru::TaxIdDniValidator.new(attributes: [ :tax_id ]).validate_each(self, :tax_id, tax_id)
    end
  end
end
