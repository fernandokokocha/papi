class EndpointsController < ApplicationController
  def show
    @project = Project.find_by(name: params[:project_name])
    @endpoint = Endpoint.find_by(id: params[:id])
    @version = @endpoint.version

    authorize @endpoint
    previous_endpoint = previous_version.endpoints.where(path: @endpoint.path, http_verb: @endpoint.http_verb).first
    expanded = params[:expanded].nil? ? true : parse_expanded(params[:expanded])

    unless previous_endpoint
      render partial: "endpoints/endpoint_added",
             layout: false,
             locals: { endpoint: @endpoint, expanded: expanded }
      return
    end

    render partial: "endpoints/endpoint_diff",
           layout: false,
           locals: { endpoint: @endpoint, previous_endpoint: previous_endpoint, expanded: expanded }
  end

  private

  def parse_expanded(expanded)
    expanded != "false"
  end

  def previous_version
    return @version.candidate.base_version unless @version.project
    @version.previous
  end
end
