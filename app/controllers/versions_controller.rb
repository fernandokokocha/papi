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
    @version = Version.new(params[:version])
    if @version.save
      redirect_to project_version_path(@version.project, @version)
    else
      render :new, status: :unprocessable_entity
    end
  end
  def index
    @versions = Version.find_by(project: params[:project_id])
  end
end
