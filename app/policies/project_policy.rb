class ProjectPolicy < ApplicationPolicy
  def create?
    @user.group === @record.group
  end
end
