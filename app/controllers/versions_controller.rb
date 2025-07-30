class VersionsController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @version = Version.find_by!(name: params[:name], project: @project)
    authorize @version
    @previous_version = @version.previous
    @next_version = @version.next

    @categorized_endpoints = Version::CategorizeByName.new(@previous_version.endpoints, @version.endpoints).call
    @categorized_entities = Version::CategorizeByName.new(@previous_version.entities, @version.entities).call
  end
end
