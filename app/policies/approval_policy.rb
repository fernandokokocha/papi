class ApprovalPolicy < ApplicationPolicy
  def create?
    candidate.project.group === @user.group && candidate.author != @user && candidate.open?
  end

  def destroy?
    create?
  end

  private

  def candidate
    @record.candidate
  end
end
