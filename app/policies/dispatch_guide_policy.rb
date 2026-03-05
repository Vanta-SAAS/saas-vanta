class DispatchGuidePolicy < ApplicationPolicy
  def index?
    platform_super_admin? || belongs_to_enterprise?
  end

  def show?
    platform_super_admin? || belongs_to_enterprise?
  end

  def create?
    platform_super_admin? || belongs_to_enterprise?
  end

  def update?
    platform_super_admin? || belongs_to_enterprise?
  end

  def destroy?
    platform_super_admin? || enterprise_super_admin?
  end

  def cancel?
    platform_super_admin? || belongs_to_enterprise?
  end

  def emit_document?
    platform_super_admin? || enterprise_admin?
  end

  def retry_document?
    platform_super_admin? || enterprise_admin?
  end
end
