class CommentsController < ApplicationController
  def create
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:candidate_name], project: @project)
    @comment = @candidate.comments.new(comment_params)
    @comment.author = Current.user
    if @comment.parent_id.blank?
      anchor = CommentAnchor.from_params(anchor_params)
      @comment.assign_attributes(anchor.to_columns)
      @comment.anchor_snapshot = anchor.current_output(@candidate.latest_version) if anchor.line
    end
    authorize @comment

    if @comment.save
      @comment_threads_by_anchor = @candidate.comment_threads_by_anchor
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
    params.require(:comment).permit(:scope, :part, :line, :endpoint_path, :endpoint_http_verb, :entity_name, :response_code)
  end
end
