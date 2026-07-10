class ResolutionsController < ApplicationController
  before_action :set_comment

  def create
    authorize @comment, :resolve?
    @comment.update(resolved_at: Time.current, resolved_by: Current.user)
    respond_with_thread
  end

  def destroy
    authorize @comment, :resolve?
    @comment.update(resolved_at: nil, resolved_by: nil)
    respond_with_thread
  end

  private

  def set_comment
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.find(params[:comment_id])
  end

  def respond_with_thread
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to project_candidate_path(@project.name, @candidate.name) }
    end
  end
end
