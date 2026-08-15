class ApprovalsController < ApplicationController
  before_action :set_candidate

  def create
    @approval = @candidate.approvals.build(user: Current.user)
    authorize @approval
    @approval.save
    redirect_to project_candidate_path(@project.name, @candidate.name)
  end

  def destroy
    @approval = @candidate.approvals.find_by!(user: Current.user)
    authorize @approval
    @approval.destroy
    redirect_to project_candidate_path(@project.name, @candidate.name)
  end

  private

  def set_candidate
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
  end
end
