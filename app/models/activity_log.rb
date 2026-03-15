class ActivityLog < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :enterprise, optional: true

  validates :controller_name, :action_name, :http_method, :path, :performed_at, presence: true

  scope :recent, -> { order(performed_at: :desc) }
  scope :for_enterprise, ->(enterprise) { where(enterprise: enterprise) }
  scope :for_user, ->(user) { where(user: user) }
  scope :for_record, ->(record) { where(record_type: record.class.name, record_id: record.id) }
  scope :by_controller, ->(name) { where(controller_name: name) }
  scope :by_action, ->(name) { where(action_name: name) }
end
