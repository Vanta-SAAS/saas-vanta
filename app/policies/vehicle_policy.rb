class VehiclePolicy < ApplicationPolicy
  def index?
    platform_super_admin? || belongs_to_enterprise?
  end

  def show?
    platform_super_admin? || belongs_to_enterprise?
  end

  def create?
    can_manage?
  end

  def update?
    can_manage?
  end

  def destroy?
    platform_super_admin? || enterprise_super_admin?
  end
end
