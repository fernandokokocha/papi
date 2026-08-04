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

  def edit?
    @user.group === @record.project.group && @user.admin? && @record.open?
  end

  def update?
    @user.group === @record.project.group && @user.admin? && @record.open?
  end

  def merge?
    @user.group === @record.project.group && @user.admin? && @record.open?
  end

  def reject?
    @user.group === @record.project.group && @user.admin? && @record.open?
  end
end
