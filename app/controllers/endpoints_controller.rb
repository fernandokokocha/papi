class EndpointsController < ApplicationController
  def show
    @project = Project.find_by(name: params[:project_name])
    @endpoint = Endpoint.find_by(id: params[:id])
    @version = @endpoint.version

    authorize @endpoint

    candidate_project = @endpoint.version.project || @endpoint.version.candidate&.project
    @candidate = Candidate.find_by(name: params[:candidate], project: candidate_project)

    expanded = params[:expanded].nil? ? true : parse_expanded(params[:expanded])

    case params[:kind]
    when "new"
      respond_to do |format|
        format.html { render partial: "endpoints/endpoint_new", layout: false, locals: { endpoint: @endpoint, expanded: expanded } }
      end
      return
    when "removed"
      respond_to do |format|
        format.html { render partial: "endpoints/endpoint_removed", layout: false, locals: { endpoint: @endpoint, expanded: expanded } }
      end
      return
    end

    base_version = @project.versions.find_by(name: params[:base])
    previous_endpoint = base_version &&
      Endpoint.find_by_identity(base_version, @endpoint.path, Endpoint.http_verbs[@endpoint.http_verb])

    unless previous_endpoint
      respond_to do |format|
        format.html { render partial: "endpoints/endpoint_new", layout: false, locals: { endpoint: @endpoint, expanded: expanded } }
      end
      return
    end

    respond_to do |format|
      format.html { render partial: "endpoints/endpoint_diff", layout: false, locals: { endpoint: @endpoint, previous_endpoint: previous_endpoint, expanded: expanded } }
    end
  end

  private

  def parse_expanded(expanded)
    expanded != "false"
  end
end
