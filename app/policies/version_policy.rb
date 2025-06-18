class VersionPolicy < ApplicationPolicy
  def show?
    @user.group === @record.project.group
  end

  def new?
    @user.group === @record.project.group
  end

  def create?
    @user.group === @record.project.group
  end
end
