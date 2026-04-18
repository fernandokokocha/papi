class EndpointsController < ApplicationController
  def show
    @project = Project.find_by(name: params[:project_name])
    @endpoint = Endpoint.find_by(id: params[:id])
    @version = @endpoint.version

    authorize @endpoint
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

    previous_endpoint = previous_version&.endpoints&.where(path: @endpoint.path, http_verb: @endpoint.http_verb)&.first

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

  def previous_version
    return @version.candidate.base_version unless @version.project
    @version.previous
  end
end
