class RejectionsController < ApplicationController
  def create
    redirect_to project_candidate_path(project_name: params[:project_name], name: params[:candidate_name])
  end
end
