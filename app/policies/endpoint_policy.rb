class EndpointPolicy < ApplicationPolicy
  def show?
    VersionPolicy.new(@user, @record.version).show?
  end
end
