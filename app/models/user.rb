class User < ApplicationRecord
  # Allow password to be nil for invited users (pending status)
  has_secure_password validations: false

  # Associations
  has_many :sessions, dependent: :destroy
  has_many :user_enterprises
  has_many :enterprises, through: :user_enterprises
  has_many :user_enterprise_roles, through: :user_enterprises
  has_many :roles, through: :user_enterprise_roles
  has_many :user_fields, dependent: :destroy
  has_many :bulk_imports, dependent: :nullify
  has_many :created_purchase_orders, class_name: "PurchaseOrder", foreign_key: :created_by_id, dependent: :restrict_with_error
  has_many :created_customer_quotes, class_name: "CustomerQuote", foreign_key: :created_by_id, dependent: :restrict_with_error
  has_many :sold_customer_quotes, class_name: "CustomerQuote", foreign_key: :seller_id, dependent: :restrict_with_error

  # Validations
  validates :first_name, :first_last_name, :email_address, presence: true
  validates :email_address, uniqueness: true

  # Require password only for active users (not for pending invitations)
  validates :password, presence: true, length: { minimum: 8 }, if: :password_required?
  validates :password, confirmation: true, if: :password_required?

  # Enums
  enum :status, {
    pending: "pending",
    active: "active",
    inactive: "inactive"
  }

  enum :platform_role, {
    standard: "standard",
    super_admin: "super_admin"
  }

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  # Generate a unique invitation token and mark as sent
  #
  # @return [Boolean] true if invitation was generated successfully, false otherwise
  def generate_invitation_token!
    self.invitation_token = SecureRandom.urlsafe_base64(32)
    self.invitation_sent_at = Time.current
    self.status = :pending
    self.invitation_accepted_at = nil
    save!
  end

  # Check if invitation token is still valid (expires after 7 days)
  #
  # @return [Boolean] true if invitation is still valid, false otherwise
  def invitation_valid?
    return false if invitation_token.blank?
    return false if invitation_accepted_at.present?
    return false if invitation_sent_at.blank?

    invitation_sent_at > 7.days.ago
  end

  # Accept invitation by setting password and activating user
  #
  # @param password [String] the password to set for the user
  # @param password_confirmation [String] the password confirmation to set for the user
  #
  # @return [Boolean] true if invitation was accepted successfully, false otherwise
  def accept_invitation!(password, password_confirmation)
    return false unless invitation_valid?

    self.password = password
    self.password_confirmation = password_confirmation
    self.invitation_accepted_at = Time.current
    self.status = :active
    self.invitation_token = nil

    save
  end

  # Check if user has accepted invitation
  #
  # @return [Boolean] true if user has accepted invitation, false otherwise
  def invitation_accepted?
    invitation_accepted_at.present?
  end

  # Check if user is pending invitation
  #
  # @return [Boolean] true if user is pending invitation, false otherwise
  def invitation_pending?
    pending? && invitation_token.present? && !invitation_accepted?
  end

  def combobox_display
    "#{first_name} #{first_last_name}"
  end

  # Get the user's role slugs for a specific enterprise
  #
  # @param enterprise [Enterprise] the enterprise to get roles for
  #
  # @return [Array<String>] array of role slugs
  def roles_for(enterprise)
    return [] unless enterprise

    user_enterprises
      .includes(:roles)
      .find_by(enterprise: enterprise)
      &.roles
      &.pluck(:slug) || []
  end

  # Check if user has a specific role in an enterprise
  #
  # @param enterprise [Enterprise] the enterprise to check
  # @param role_slug [String, Symbol] the role slug to check
  #
  # @return [Boolean]
  def has_role?(enterprise, role_slug)
    roles_for(enterprise).include?(role_slug.to_s)
  end

  # Helpers para datos extendidos (user_fields)
  def driving_license_number
    user_fields.find_by(field_type: "driving_license_number")&.value
  end

  def doc_number_for_sunat
    user_fields.find_by(field_type: "doc_number")&.value
  end

  def doc_type_for_sunat
    user_fields.find_by(field_type: "doc_type")&.value || "dni"
  end

  def full_name
    "#{first_name} #{first_last_name}"
  end

  private

  # Validates if password is required when
  # 1. Creating a new user with active status (not pending)
  # 2. Updating password (password field is present)
  #
  # @return [Boolean] true if password is required, false otherwise
  def password_required?
    return true if password.present?

    return !pending? if new_record?

    false
  end
end
