class VersionsController < ApplicationController
  def show
    @version = Version.find(params[:id])
    @previous_version = @version.previous
    @next_version = @version.next
  end

  def new
    @project = Project.find(params[:project_id])
    @latest_version = @project.latest_version
    @version = @latest_version.amoeba_dup
    @version.name = "New Version"
    @version.created_at = Time.now
    @version.updated_at = Time.now
    @version.order = @latest_version.order + 1
  end

  def create
    params.permit!
    params[:version][:project_id] = params[:project_id]
    roots = []
    params[:version][:endpoints_attributes].map do |endpoint_attr|
      roots << RootParser.new.parse_object(endpoint_attr[:original_endpoint_root])
    end
    @version = Version.new(params[:version])
    @version.endpoints.zip(roots) do |endpoint, endpoint_root|
      endpoint.endpoint_root_id = endpoint_root.id
      endpoint.endpoint_root_type = "ObjectNode"
    end

    if @version.save
      redirect_to project_version_path(id: @version.id, project_id: @version.project.id)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def index
    @versions = Version.find_by(project: params[:project_id])
  end
end
