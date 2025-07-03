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

  def new
    @project = Project.find_by!(name: params[:project_name])
    @latest_version = @project.latest_version
    if @latest_version
      @version = @latest_version.amoeba_dup
      @version.order = @latest_version.order + 1
    else
      @version = Version.new(project: @project)
      @version.order = 1
    end
    @version.name = "v#{@version.order}"
    @version.created_at = Time.now
    @version.updated_at = Time.now
    authorize @version
  end

  def create
    params.permit!
    (params[:version][:entities_attributes] || []).each do |entity_attr|
      root = JSONSchemaParser.new.parse_value(entity_attr[:original_root])
      root.save
      entity_attr[:root_id] = root.id
      entity_attr[:root_type] = root.class.name
    end

    # first save, with entities bet without endpoints
    endpoints_attrs = params[:version][:endpoints_attributes]
    params[:version][:endpoints_attributes] = []
    @version = Version.new(params[:version])
    authorize @version

    unless @version.save
      redirect_to new_project_version_path(project_name: @version.project.name)
      return
    end

    # inputs and outputs may refer to entities and Node::Entity has a reference to Entity.
    # All in all this needs to be done separately
    valid_entities = @version.entities
    (endpoints_attrs || []).each do |endpoint_attr|
      puts " #### " + endpoint_attr[:original_output_string]
      output = JSONSchemaParser.new(valid_entities).parse_value(endpoint_attr[:original_output_string])
      puts " #### " + endpoint_attr[:original_input_string]
      input = JSONSchemaParser.new(valid_entities).parse_value(endpoint_attr[:original_input_string])

      Endpoint.create!(url: endpoint_attr[:url],
                       http_verb: endpoint_attr[:http_verb],
                       input: input,
                       output: output,
                       original_input_string: endpoint_attr[:original_input_string],
                       original_output_string: endpoint_attr[:original_output_string],
                       note: endpoint_attr[:note],
                       auth: endpoint_attr[:auth],
                       version: @version,
                       responses_attributes: format_responses(endpoint_attr[:responses])
      )
    end

    redirect_to project_version_path(name: @version.name, project_name: @version.project.name)
  end

  private

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |key, value|
      { code: key, note: value }
    end
  end
end
