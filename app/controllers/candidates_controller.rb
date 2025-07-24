class CandidatesController < ApplicationController
  def show
    @project = Project.find_by!(name: params[:project_name])
    @candidate = Candidate.find_by!(name: params[:name], project: @project)
    authorize @candidate
    @version = @candidate.latest_version
    @previous_version = @project.latest_version
    @next_version = Version.null_version(@project)

    categorized_endpoints = CategorizeEndpoints.new(@previous_version, @version).call
    @existing_endpoints = categorized_endpoints[:existing]
    @added_endpoints = categorized_endpoints[:added]
    @removed_endpoints = categorized_endpoints[:removed]

    categorized_entities = CategorizeEntities.new(@previous_version, @version).call
    @existing_entities = categorized_entities[:existing]
    @added_entities = categorized_entities[:added]
    @removed_entities = categorized_entities[:removed]

    render "versions/show"
  end

  def new
    @project = Project.find_by!(name: params[:project_name])
    @latest_candidate = @project.latest_candidate
    @candidate = Candidate.new
    @candidate.project = @latest_candidate.project
    @candidate.order = @latest_candidate.order + 1
    @candidate.name = "rc#{@candidate.order}"
    @candidate.created_at = Time.zone.now
    @candidate.updated_at = Time.zone.now
    authorize @candidate

    @latest_version = @project.latest_version
    @version = @latest_version.amoeba_dup
    @version.order = 1
    @version.name = "#{@candidate.name}-v#{@version.order}"
    @version.created_at = Time.zone.now
    @version.updated_at = Time.zone.now
    @version.candidate = @candidate
  end

  def create
    params.permit!

    @candidate = Candidate.create!(params[:candidate])
    authorize @candidate

    (params[:version][:entities_attributes] || []).each do |entity_attr|
      root = JSONSchemaParser.new.parse_value(entity_attr[:original_root])
      root.save
      entity_attr[:root_id] = root.id
      entity_attr[:root_type] = root.class.name
    end

    # first save, with entities bet without endpoints
    endpoints_attrs = params[:version][:endpoints_attributes]
    params[:version][:endpoints_attributes] = []
    params[:version][:candidate_id] = @candidate.id
    @version = Version.new(params[:version])

    unless @version.save
      puts @version.errors.full_messages
      redirect_to new_project_candidate_path(project_name: @candidate.project.name)
      return
    end

    # inputs and outputs may refer to entities and Node::Entity has a reference to Entity.
    # All in all this needs to be done separately
    valid_entities = @version.entities
    (endpoints_attrs || []).each do |endpoint_attr|
      output = JSONSchemaParser.new(valid_entities).parse_value(endpoint_attr[:original_output_string])
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

    redirect_to project_candidate_path(name: @candidate.name, project_name: @candidate.project.name)
  end

  private

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |key, value|
      { code: key, note: value }
    end
  end
end
