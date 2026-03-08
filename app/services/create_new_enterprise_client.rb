class CreateNewEnterpriseClient < BaseService
  def initialize(params, user_id:)
    super()
    @user_id = user_id
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      create_enterprise!
      invite_users!

      set_as_valid!
    end
  rescue StandardError => e
    add_error(e.message)
    set_as_invalid!
  end

  private

  def create_enterprise!
    create_enterprise_service.call

    return if create_enterprise_service.valid?

    raise StandardError, create_enterprise_service.errors
  end

  def invite_users!
    user_params.each_with_index do |new_user_data, index|
      invite_user_service = Users::InviteUserToEnterprise.new(
        enterprise:,
        user_email: new_user_data[:user_email],
        first_name: new_user_data[:first_name],
        first_last_name: new_user_data[:first_last_name],
        second_last_name: new_user_data[:second_last_name],
        role_slug: new_user_data[:role_slug]
      )

      invite_user_service.call

      next if invite_user_service.valid?

      raise StandardError, "Error al invitar usuario #{index + 1} (#{new_user_data[:user_email]}): #{invite_user_service.errors}"
    end
  end

  def enterprise
    @enterprise ||= create_enterprise_service.enterprise
  end

  def create_enterprise_service
    @create_enterprise_service ||= ::Enterprises::CreateEnterprise.new(user_id: @user_id, params: enterprise_params)
  end

  def enterprise_params
    @params.permit(:tax_id, :enterprise_type, :social_reason, :comercial_name, :address, :email, :phone_number, :logo,
                   settings_attributes: [ :primary_color, :secondary_color ])
  end

  def user_params
    @params.permit(users: [ :user_email, :first_name, :first_last_name, :second_last_name, :role_slug ])[:users] || []
  end
end
