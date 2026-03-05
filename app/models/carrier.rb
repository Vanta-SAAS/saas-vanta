class Carrier < ApplicationRecord
  belongs_to :enterprise

  has_many :dispatch_guides, dependent: :restrict_with_error

  validates :ruc, presence: true, uniqueness: { scope: :enterprise_id, message: "ya esta registrado en esta empresa" }
  validates :name, presence: true

  enum :status, { active: "active", inactive: "inactive" }

  scope :active, -> { where(status: :active) }

  def combobox_display
    "#{name} (#{ruc})"
  end
end
