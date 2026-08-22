class EndpointCardsController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @candidate = @project.candidates.find_by(name: params[:candidate])
    endpoint = Endpoint.find(params[:endpoint_id])
    authorize endpoint

    endpoint.annotation = params[:annotation]
    endpoint.previous = previous_endpoint(endpoint)

    render partial: "endpoints/card_body", layout: false, locals: {
      endpoint: endpoint,
      expanded: params[:expanded].to_s.split(","),
      base: params[:base],
      project_name: @project.name
    }
  end

  private

  def previous_endpoint(endpoint)
    return nil if params[:base].blank? || endpoint.annotation.in?(%w[added removed])

    base_version = @project.versions.find_by!(name: params[:base])
    Endpoint.find_by_identity(base_version, endpoint.path, Endpoint.http_verbs[endpoint.http_verb])
  end
end
