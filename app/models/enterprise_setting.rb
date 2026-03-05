class EnterpriseSetting < ApplicationRecord
  belongs_to :enterprise

  VALID_HEX_COLOR = /\A#[0-9a-fA-F]{6}\z/

  validates :primary_color, format: { with: VALID_HEX_COLOR }, allow_blank: true
  validates :secondary_color, format: { with: VALID_HEX_COLOR }, allow_blank: true

  before_save :normalize_colors

  private

  def normalize_colors
    self.primary_color = primary_color&.downcase&.strip.presence
    self.secondary_color = secondary_color&.downcase&.strip.presence
  end
end
