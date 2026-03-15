module Trackable
  extend ActiveSupport::Concern

  included do
    after_action :log_activity
  end

  private

  def log_activity
    ActivityLog.create!(
      user: Current.user,
      enterprise: current_enterprise,
      controller_name: controller_name,
      action_name: action_name,
      record_type: tracked_record_type,
      record_id: tracked_record_id,
      request_params: sanitized_params,
      ip_address: request.remote_ip,
      http_method: request.method,
      path: request.fullpath,
      performed_at: Time.current
    )
  rescue => e
    Rails.logger.error("ActivityLog error: #{e.message}")
  end

  def tracked_record_type
    controller_name.classify
  rescue
    nil
  end

  def tracked_record_id
    params[:id]
  end

  def sanitized_params
    request.filtered_parameters.except("controller", "action")
  end
end
