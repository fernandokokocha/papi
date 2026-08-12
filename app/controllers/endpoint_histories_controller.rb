class EndpointHistoriesController < ApplicationController
  def show
    @endpoint = Endpoint.find(params[:endpoint_id])
    authorize @endpoint
    @project = Project.find_by!(name: params[:project_name])
    @milestones = History.for_endpoint(@project, @endpoint).milestones
  end
end
