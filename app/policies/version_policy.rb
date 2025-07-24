class VersionPolicy < ApplicationPolicy
  def show?
    CandidatePolicy.new(@user, @record.candidate).show?
  end
end
