class OpenAPIImportsController < ApplicationController
  def new
    @project = Project.find_by!(name: params[:project_name])
    authorize Candidate.new(project: @project)
  end

  def create
    @project = Project.find_by!(name: params[:project_name])
    authorize Candidate.new(project: @project)

    import = OpenAPI::Import.new(@project, params.require(:document).read)
    import.call

    redirect_to project_candidate_path(project_name: @project.name, name: import.candidate.name)
  rescue OpenAPI::Invalid => e
    redirect_to new_project_openapi_import_path(project_name: @project.name), alert: e.message
  end
end
