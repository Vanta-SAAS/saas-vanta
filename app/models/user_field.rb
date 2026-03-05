class UserField < ApplicationRecord
  belongs_to :user

  VALID_FIELD_TYPES = %w[driving_license_number doc_number doc_type].freeze

  validates :field_type, presence: true, inclusion: { in: VALID_FIELD_TYPES }
  validates :value, presence: true
  validates :field_type, uniqueness: { scope: :user_id, message: "ya existe para este usuario" }
end
