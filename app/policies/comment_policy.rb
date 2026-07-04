class CommentPolicy < ApplicationPolicy
  def create?
    @user.group === @record.candidate.project.group
  end
end
