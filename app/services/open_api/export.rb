class OpenAPI::Export
  # 3.0 cannot express (string|number|null) — its nullable: true is not a union
  # member. 3.2 adds nothing Papi uses and is strictly compatible with 3.1, so
  # declaring 3.1 only widens the tooling that accepts the document.
  SPEC_VERSION = "3.1.0"
  MEDIA_TYPE = "application/json"

  def initialize(version)
    @version = version
  end

  def call
    document = {
      "openapi" => SPEC_VERSION,
      "info" => { "title" => @version.project.name, "version" => @version.name },
      "paths" => paths
    }
    document["components"] = components if components.any?
    document
  end

  private

  def components
    result = {}
    result["securitySchemes"] = security_schemes if @version.auth_methods.any?
    result["schemas"] = schemas if @version.entities.any?
    result
  end

  def security_schemes
    @version.auth_methods.to_h do |auth_method|
      scheme = { "type" => "http", "scheme" => auth_method.kind }
      scheme["description"] = auth_method.note if auth_method.note.present?
      [ auth_method.name, scheme ]
    end
  end

  def paths
    @version.endpoints.group_by { |endpoint| templated_path(endpoint.path) }.transform_values do |endpoints|
      endpoints.to_h { |endpoint| [ endpoint.verb.downcase, operation(endpoint) ] }
    end
  end

  def templated_path(path)
    path.gsub(Endpoint::PARAM_TOKEN, '{\1}')
  end

  def operation(endpoint)
    input = endpoint.parsed_input
    parameters = parameters(endpoint)
    responses = responses(endpoint)

    operation = {}
    operation["summary"] = endpoint.note if endpoint.note.present?
    operation["security"] = [ { endpoint.auth => [] } ] if endpoint.auth.present?
    operation["parameters"] = parameters if parameters.any?
    operation["requestBody"] = { "required" => true, "content" => content(input, endpoint) } unless nothing?(input)
    operation["responses"] = responses if responses.any?
    operation
  end

  def parameters(endpoint)
    (endpoint.path_params + endpoint.query_params).map do |param|
      {
        "name" => param.name,
        "in" => param.location,
        "required" => param.location == "path" || param.required,
        "schema" => { "type" => param.kind }
      }
    end
  end

  def responses(endpoint)
    endpoint.responses.sort_by(&:code).to_h do |response|
      output = response.parsed_output

      object = { "description" => description(response) }
      object["content"] = content(output, response) unless nothing?(output)
      [ response.code, object ]
    end
  end

  def description(response)
    response.note.presence || Rack::Utils::HTTP_STATUS_CODES.fetch(response.code.to_i, response.code)
  end

  def content(node, notable)
    { MEDIA_TYPE => { "schema" => OpenAPI::ExportSchema.new(node, notes_of(notable)).call } }
  end

  def notes_of(notable)
    notable.schema_notes.to_h { |note| [ note.segments, note.body ] }
  end

  def schemas
    @version.entities.to_h { |entity| [ entity.name, OpenAPI::ExportSchema.new(entity.parsed_root, notes_of(entity)).call ] }
  end

  def nothing?(node)
    node.is_a?(Node::Nothing)
  end
end
