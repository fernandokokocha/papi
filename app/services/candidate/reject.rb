class Candidate::Reject
  attr_reader :candidate, :project, :version

  def initialize(candidate)
    @candidate = candidate
    @version = @candidate.latest_version
    @project = @candidate.project
  end

  def call
    ActiveRecord::Base.transaction do
      @candidate.reject
      @candidate.save!
    end
  end
end
