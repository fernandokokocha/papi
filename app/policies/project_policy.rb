class ProjectPolicy < ApplicationPolicy
  def show?
    @user.group === @record.group
  end

  def create?
    @user.group === @record.group
  end
end
