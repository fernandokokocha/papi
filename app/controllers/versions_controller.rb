class VersionsController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @version = Version.find_by!(name: params[:name], project: @project)
    authorize @version
    @previous_version = @version.previous
    @next_version = @version.next

    categorized_endpoints = CategorizeEndpoints.new(@previous_version, @version).call
    @existing_endpoints = categorized_endpoints[:existing]
    @added_endpoints = categorized_endpoints[:added]
    @removed_endpoints = categorized_endpoints[:removed]

    categorized_entities = CategorizeEntities.new(@previous_version, @version).call
    @existing_entities = categorized_entities[:existing]
    @added_entities = categorized_entities[:added]
    @removed_entities = categorized_entities[:removed]
  end
end
