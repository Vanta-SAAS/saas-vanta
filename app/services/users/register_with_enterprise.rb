module Users
  class RegisterWithEnterprise < BaseService
    attr_reader :user, :enterprise

    def initialize(params)
      super()
      @user_params = params[:user] || {}
      @enterprise_params = params[:enterprise] || {}
    end

    def call
      ActiveRecord::Base.transaction do
        create_user!
        create_enterprise!
        link_user_to_enterprise!
      end

      send_confirmation_email!

      self
    rescue ActiveRecord::RecordInvalid => e
      set_as_invalid!
      add_errors(e.record.errors.full_messages) if errors.empty?
      self
    end

    private

    def create_user!
      @user = User.new(@user_params)
      @user.status = :pending
      @user.platform_role = :standard
      @user.save!
    end

    def create_enterprise!
      @enterprise = Enterprise.new(@enterprise_params)
      @enterprise.status = :active
      @enterprise.save!
      EnterpriseSetting.create!(enterprise: @enterprise)
    end

    def link_user_to_enterprise!
      user_enterprise = UserEnterprise.create!(user: @user, enterprise: @enterprise)
      assign_super_admin_role!(user_enterprise)
    end

    def assign_super_admin_role!(user_enterprise)
      role = Role.find_by!(slug: :super_admin)
      UserEnterpriseRole.create!(user_enterprise: user_enterprise, role: role)
    end

    def send_confirmation_email!
      @user.generate_invitation_token!
      UserMailer.with(user: @user, enterprise: @enterprise).confirmation_email.deliver_later
    end
  end
end
