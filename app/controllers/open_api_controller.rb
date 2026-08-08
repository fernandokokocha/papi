class OpenAPIController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @version = Version.find_by!(name: params[:version_name], project: @project)
    authorize @version

    send_data JSON.pretty_generate(OpenAPI::Export.new(@version).call),
      filename: "#{@project.name}-#{@version.name}.json",
      type: "application/json"
  end
end
