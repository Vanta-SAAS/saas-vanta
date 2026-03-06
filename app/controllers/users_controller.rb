class UsersController < ApplicationController
  before_action :require_enterprise_selected
  before_action :set_user, only: %i[show edit update toggle_status]

  def index
    authorize User
    users = current_enterprise.users.includes(:roles).order(created_at: :desc)
    @pagy, @users = pagy(users)
  end

  def search
    authorize User, :index?
    query = params[:q].to_s.strip

    @users_results = if query.present?
      current_enterprise.users
                       .where(status: :active)
                       .where("LOWER(first_name) LIKE :q OR LOWER(first_last_name) LIKE :q OR LOWER(email_address) LIKE :q", q: "%#{query.downcase}%")
                       .order(:first_name)
                       .limit(20)
    else
      current_enterprise.users.where(status: :active).order(:first_name).limit(20)
    end

    respond_to do |format|
      format.turbo_stream
    end
  end

  def show
    authorize @user
  end

  def new
    authorize User
    @user = User.new
    @roles = available_roles
  end

  def create
    authorize User

    selected_role_ids = Array(params[:role_ids]).reject(&:blank?)
    roles = Role.where(id: selected_role_ids)

    if roles.empty?
      @user = User.new(user_params)
      @user.errors.add(:base, "Debes seleccionar al menos un rol")
      @roles = available_roles
      return render :new, status: :unprocessable_entity
    end

    service = Users::InviteUserToEnterprise.new(
      enterprise: current_enterprise,
      user_email: params[:user][:email_address],
      first_name: params[:user][:first_name],
      first_last_name: params[:user][:first_last_name],
      second_last_name: params[:user][:second_last_name],
      role_slug: roles.first.slug
    )

    service.call

    if service.valid?
      # If more than one role, add the remaining ones
      if roles.size > 1
        user = User.find_by(email_address: params[:user][:email_address])
        user_enterprise = user&.user_enterprises&.find_by(enterprise: current_enterprise)
        if user_enterprise
          roles[1..].each do |role|
            user_enterprise.user_enterprise_roles.find_or_create_by!(role: role)
          end
        end
      end
      redirect_to users_path, notice: "Usuario invitado exitosamente. Se ha enviado un correo de invitacion."
    else
      @user = User.new(user_params)
      @user.errors.add(:base, service.errors_message)
      @roles = available_roles
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    authorize @user
    @roles = available_roles
    @current_role_ids = current_role_ids_for(@user)
  end

  def update
    authorize @user

    if @user.update(user_update_params)
      update_user_roles(@user)
      redirect_to @user, notice: "Usuario actualizado exitosamente."
    else
      @roles = available_roles
      @current_role_ids = current_role_ids_for(@user)
      render :edit, status: :unprocessable_entity
    end
  end

  def toggle_status
    authorize @user

    new_status = @user.active? ? :inactive : :active
    @user.update!(status: new_status)

    status_message = @user.active? ? "activado" : "desactivado"
    redirect_to users_path, notice: "Usuario #{status_message} exitosamente."
  end

  private

  def require_enterprise_selected
    return if current_enterprise.present?

    redirect_to enterprises_path, alert: "Debes seleccionar una empresa primero."
  end

  def set_user
    @user = current_enterprise.users.find(params[:id])
  end

  def user_params
    params.require(:user).permit(
      :first_name,
      :first_last_name,
      :second_last_name,
      :email_address,
      :phone_number
    )
  end

  def user_update_params
    params.require(:user).permit(
      :first_name,
      :first_last_name,
      :second_last_name,
      :phone_number
    )
  end

  def available_roles
    if Current.user&.super_admin? || Current.user&.has_role?(current_enterprise, :super_admin)
      Role.all.order(:id)
    else
      Role.where(slug: [ :admin, :seller, :driver ]).order(:id)
    end
  end

  def current_role_ids_for(user)
    user_enterprise = user.user_enterprises.find_by(enterprise: current_enterprise)
    return [] unless user_enterprise
    user_enterprise.user_enterprise_roles.pluck(:role_id)
  end

  def update_user_roles(user)
    selected_role_ids = Array(params[:role_ids]).reject(&:blank?)
    return if selected_role_ids.empty?

    user_enterprise = user.user_enterprises.find_by(enterprise: current_enterprise)
    return unless user_enterprise

    user_enterprise.user_enterprise_roles.destroy_all
    selected_role_ids.each do |role_id|
      user_enterprise.user_enterprise_roles.create!(role_id: role_id)
    end
  end
end
