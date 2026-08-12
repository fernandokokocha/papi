class VersionsController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @version = Version.find_by!(name: params[:name], project: @project)
    authorize @version
    @previous_version = @version.previous
    @next_version = @version.next
    @comparison = Comparison.for_version(@version, params[:base])
  end
end
