class CommentsController < ApplicationController
  def create
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.new(comment_params)
    @comment.author = Current.user
    @comment.assign_attributes(scope: "candidate", part: "whole") if @comment.parent_id.blank?
    authorize @comment

    if @comment.save
      respond_to do |format|
        format.turbo_stream
        format.html { redirect_to project_candidate_path(@project.name, @candidate.name) }
      end
    else
      redirect_to project_candidate_path(@project.name, @candidate.name), alert: "Comment could not be posted."
    end
  end

  private

  def comment_params
    params.require(:comment).permit(:body, :parent_id)
  end
end
