class OpenAPI::Import
  MEDIA_TYPE = "application/json"
  SUPPORTED_SPEC_VERSION = "3."
  VERBS = {
    "get" => "verb_get",
    "post" => "verb_post",
    "put" => "verb_put",
    "patch" => "verb_patch",
    "delete" => "verb_delete"
  }.freeze
  STATUS_CODE = /\A\d{3}\z/
  FALLBACK_CODE = "200"
  TEMPLATED_SEGMENT = /\A\{([^{}]+)\}\z/
  PARAM_KINDS = { "integer" => "number", "number" => "number", "boolean" => "boolean" }.freeze
  NOTE_SEPARATOR = " — "

  attr_reader :candidate

  def initialize(project, content, author: Current.user)
    @project = project
    @content = content
    @author = author
  end

  def call
    raise OpenAPI::Invalid, "#{@project.name} already has an open candidate" unless @project.can_create_candidate?
    raise OpenAPI::Invalid, "This is not an OpenAPI 3 document" unless supported?

    ActiveRecord::Base.transaction do
      @candidate = Candidate.create!(candidate_attributes)
      version = Version.create!(version_attributes)

      raise OpenAPI::Invalid, "There is nothing to review: this document is the spec Papi already holds" if unchanged?(version)
    end
  rescue ActiveRecord::RecordInvalid => e
    raise OpenAPI::Invalid, "Papi cannot hold this document: #{e.record.errors.full_messages.to_sentence}"
  end

  private

  # JSON is a subset of YAML, so one parser reads both. Dates are permitted
  # because an unquoted example or version scalar is one.
  def document
    @document ||= YAML.safe_load(@content, aliases: true, permitted_classes: [ Date, Time ])
  rescue Psych::SyntaxError => e
    raise OpenAPI::Invalid, "This file is neither JSON nor YAML: #{e.problem}"
  end

  def supported?
    document.is_a?(Hash) && document["openapi"].to_s.start_with?(SUPPORTED_SPEC_VERSION)
  end

  def candidate_attributes
    order = @project.latest_candidate.order + 1

    {
      project: @project,
      name: "rc#{order}",
      order: order,
      base_version_id: base_version.id,
      author: @author
    }
  end

  def base_version
    @base_version ||= @project.latest_version
  end

  # A candidate is a pull request, and one that changes nothing has nothing to
  # review. The editor asks the same question of its own form, but by comparing
  # serialized JSON; here it goes through Diff, so a reordered object counts as
  # the no_change it is.
  def unchanged?(version)
    categorized = Version::CategorizeByName.new(base_version.endpoints, version.endpoints).call +
      Version::CategorizeByName.new(base_version.entities, version.entities).call

    categorized.all? { |record| record.annotation == "unchanged" }
  end

  def version_attributes
    {
      candidate: @candidate,
      name: "#{@candidate.name}-v1",
      order: 1,
      endpoints: endpoints,
      entities: rooted_entities
    }
  end

  # Node::Entity refers to an Entity record, so the entities exist before any
  # schema is read and are filled in once every reference can be resolved.
  def entities
    @entities ||= schemas.keys.to_h { |name| [ name, Entity.new(name: capitalized(name)) ] }
  end

  def schemas
    document.dig("components", "schemas") || {}
  end

  def rooted_entities
    entities.each { |name, entity| entity.root = node(schemas.fetch(name)).serialize }.values
  end

  def capitalized(name)
    name.sub(/\A./, &:upcase)
  end

  def endpoints
    (document["paths"] || {}).flat_map do |template, path_item|
      path = papi_path(template)
      next [] if path.nil?

      VERBS.filter_map do |verb, http_verb|
        operation = path_item[verb]
        endpoint(path, http_verb, operation, path_item["parameters"] || []) if operation
      end
    end
  end

  # A segment holding anything besides one whole param cannot be routed by
  # Endpoint#serves?, so the endpoint is skipped rather than mangled.
  def papi_path(template)
    segments = template.split("/").map do |segment|
      next segment unless segment.include?("{")

      name = segment[TEMPLATED_SEGMENT, 1]
      return nil if name.nil?

      ":#{param_name(name)}"
    end

    segments.join("/")
  end

  def param_name(name)
    sanitized = name.gsub(/[^A-Za-z0-9_]/, "_")

    sanitized.match?(/\A\d/) ? "_#{sanitized}" : sanitized
  end

  def endpoint(path, http_verb, operation, shared_params)
    Endpoint.new(
      path: path,
      http_verb: http_verb,
      note: note(operation),
      input: body(operation.dig("requestBody", "content")),
      params: params(shared_params + (operation["parameters"] || [])),
      responses: responses(operation["responses"] || {})
    )
  end

  def note(operation)
    [ operation["summary"], operation["description"] ].compact_blank.join(NOTE_SEPARATOR)
  end

  # An operation's own parameter overrides the path item's parameter of the
  # same name and location, which is what the later entry of the pair is.
  def params(declared)
    routed = declared.select { |param| EndpointParam::LOCATIONS.include?(param["in"]) }

    routed.index_by { |param| [ param["name"], param["in"] ] }.values.map do |param|
      EndpointParam.new(
        name: param_name(param["name"]),
        kind: PARAM_KINDS.fetch(param.dig("schema", "type"), "string"),
        location: param["in"],
        required: param["in"] == "path" || param["required"] == true
      )
    end
  end

  # The editor refuses to submit an endpoint with no responses, so an import
  # must not leave one behind. An operation answering only "default" or "2XX"
  # keeps that response under a code Papi can hold — imprecise, and the whole
  # endpoint would be unusable otherwise.
  def responses(declared)
    keyed = declared.filter_map { |code, response| response(code, response) if code.match?(STATUS_CODE) }
    return keyed if keyed.any?

    [ response(FALLBACK_CODE, declared["default"] || declared.values.first || {}) ]
  end

  def response(code, declared)
    Response.new(code: code, note: declared["description"].to_s, output: body(declared["content"]))
  end

  def body(content)
    return "" if content.nil?

    _type, media = content.find { |type, _body| type.split(";").first.strip == MEDIA_TYPE }
    return "" if media.nil? || media["schema"].nil?

    declared = node(media["schema"])
    nothing_to_declare?(declared) ? "" : declared.serialize
  end

  # Papi has no map type, so additionalProperties arrives as an object with no
  # attributes. A whole value says that better as nothing — which is a whole
  # value only: nested, and at an entity root, `{}` has to stand.
  def nothing_to_declare?(node)
    node.is_a?(Node::Object) && node.object_attributes.empty?
  end

  def node(schema)
    OpenAPI::ImportSchema.new(schema, entities, schemas).call
  end
end
