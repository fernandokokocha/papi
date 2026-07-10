class CommentPolicy < ApplicationPolicy
  def create?
    @user.group === @record.candidate.project.group
  end

  def resolve?
    @user == @record.candidate.author
  end
end
