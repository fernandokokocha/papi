class Candidate::Merge
  attr_reader :candidate, :project, :version

  def initialize(candidate)
    @candidate = candidate
    @version = @candidate.latest_version
    @project = @candidate.project
  end

  def call
    ActiveRecord::Base.transaction do
      @version.update(project: @project,
                      order: @project.next_version_order,
                      name: @project.next_version_name
      )

      @candidate.merge
      @candidate.save!
    end
  end
end
