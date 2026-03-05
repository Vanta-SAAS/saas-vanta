class DispatchGuideItem < ApplicationRecord
  belongs_to :dispatch_guide
  belongs_to :product, optional: true

  validates :description, presence: true
  validates :quantity, presence: true, numericality: { greater_than: 0 }
  validates :unit_code, presence: true
end
