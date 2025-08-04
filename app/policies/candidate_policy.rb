class CandidatePolicy < ApplicationPolicy
  def show?
    @user.group === @record.project.group
  end

  def new?
    @user.group === @record.project.group
  end

  def create?
    @user.group === @record.project.group
  end

  def merge?
    @user.group === @record.project.group && @user.admin?
  end

  def reject?
    @user.group === @record.project.group && @user.admin?
  end
end
