class Candidate::Create
  attr_reader :params, :candidate, :version

  def initialize(params)
    @params = params
  end

  def call
    ActiveRecord::Base.transaction do
      # STEP 1: assign base version if there is any version in the project
      project = Project.find(params[:candidate][:project_id])
      base_version = project.latest_version
      params[:candidate][:base_version_id] = base_version.id || nil

      # STEP 2: Create candidate
      @candidate = Candidate.create!(params[:candidate])
      params[:version][:candidate_id] = @candidate.id

      # STEP 3: Parse and save entities
      (params[:version][:entities_attributes] || []).each do |entity_attr|
        root = JSONSchemaParser.new.parse_value(entity_attr[:original_root])
        root.save
        entity_attr[:root_id] = root.id
        entity_attr[:root_type] = root.class.name
      end

      # STEP 4: Clear endpoint attributes and save them for later
      endpoints_attrs = params[:version][:endpoints_attributes]
      params[:version][:endpoints_attributes] = []

      # STEP 5: Try and save version without endpoints
      @version = Version.new(params[:version])
      raise ActiveRecord::RecordInvalid unless @version.save

      # STEP 6: Save endpoints.
      # It's a separate step because on this stage entities should be already in the database.
      # Inputs and outputs may refer to entity node and Node::Entity references Entity.
      parser = JSONSchemaParser.new(@version.entities)
      (endpoints_attrs || []).each do |endpoint_attr|
        output = parser.parse_value(endpoint_attr[:original_output_string])
        input = parser.parse_value(endpoint_attr[:original_input_string])

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
    end
  end

  private

  def format_responses(responses_hash)
    return [] unless responses_hash
    responses_hash.to_hash.entries.map do |key, value|
      { code: key, note: value }
    end
  end
end
