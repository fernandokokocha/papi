class Candidate::Reject
  attr_reader :candidate, :project, :version

  def initialize(candidate, decided_by: Current.user)
    @candidate = candidate
    @version = @candidate.latest_version
    @project = @candidate.project
    @decided_by = decided_by
  end

  def call
    ActiveRecord::Base.transaction do
      @candidate.reject
      @candidate.decided_by = @decided_by
      @candidate.decided_at = Time.current
      @candidate.save!
    end
  end
end
