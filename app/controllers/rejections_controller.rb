class RejectionsController < ApplicationController
  def create
    @candidate = Candidate.find_by(name: params[:candidate_name])
    authorize @candidate, :reject?
    service = Candidate::Reject.new(@candidate)
    service.call
    redirect_to root_path
  rescue ActiveRecord::RecordInvalid => e
    redirect_to project_candidate_path(project_name: @candidate.project.name, name: @candidate.name)
  end
end
