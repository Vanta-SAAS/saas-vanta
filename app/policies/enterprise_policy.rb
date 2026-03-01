class EnterprisePolicy < ApplicationPolicy
  def edit?
    platform_super_admin? || enterprise_super_admin?
  end

  def update?
    platform_super_admin? || enterprise_super_admin?
  end

  def sunat?
    platform_super_admin? || enterprise_super_admin? || enterprise_admin?
  end

  def show?
    sunat?
  end

  def manage?
    platform_super_admin? || enterprise_super_admin?
  end
end
