class Vehicle < ApplicationRecord
  belongs_to :enterprise

  has_many :dispatch_guides, dependent: :restrict_with_error

  validates :plate, presence: true, uniqueness: { scope: :enterprise_id, message: "ya esta registrada en esta empresa" }

  enum :status, { active: "active", inactive: "inactive" }

  scope :active, -> { where(status: :active) }

  def combobox_display
    label = plate
    label += " - #{brand}" if brand.present?
    label += " #{model}" if model.present?
    label
  end
end
