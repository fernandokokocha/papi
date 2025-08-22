class MergesController < ApplicationController
  def create
    @project = Project.find_by(name: params[:project_name])
    @candidate = Candidate.find_by(name: params[:candidate_name], project: @project)
    authorize @candidate, :merge?
    service = Candidate::Merge.new(@candidate)
    service.call
    redirect_to project_version_path(project_name: service.project.name, name: service.version.name)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to project_candidate_path(project_name: @candidate.project.name, name: @candidate.name)
  end
end
