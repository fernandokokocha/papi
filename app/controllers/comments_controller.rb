class CommentsController < ApplicationController
  def create
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    service = Comment::Create.new(@candidate, comment_params, anchor_params)
    @comment = service.comment
    authorize @comment

    if service.call
      @reopened_parent = service.reopened_parent
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

  def anchor_params
    params.require(:comment).permit(:scope, :part, :line, :endpoint_path, :endpoint_http_verb, :entity_name, :response_code, :param_name, :param_location)
  end
end
