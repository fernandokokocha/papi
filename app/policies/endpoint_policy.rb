class EndpointPolicy < ApplicationPolicy
  def show?
    @user.group === @record.version.project.group
  end
end
