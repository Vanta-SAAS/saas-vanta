class FeatureModule < ApplicationRecord
  has_many :children, class_name: "FeatureModule", foreign_key: :parent_id, dependent: :destroy
  belongs_to :parent, class_name: "FeatureModule", optional: true
  has_many :enterprise_modules, dependent: :destroy

  validates :key, presence: true, uniqueness: true
  validates :name, presence: true
  validates :kind, presence: true, inclusion: { in: %w[module option] }

  scope :roots, -> { where(parent_id: nil) }
  scope :ordered, -> { order(:position) }

  def root?
    parent_id.nil?
  end

  def option?
    kind == "option"
  end

  def module?
    kind == "module"
  end
end
