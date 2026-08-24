# The form reads as the diff, so the same reading answers both halves of the
# submit bar: what each card is annotated with, and whether anything the page
# holds stops the candidate from being saved.
class SchemaForm::Checks
  Problem = Data.define(:anchor, :subject, :message)

  def initialize(endpoints:, blocks:, auth_methods:, base:)
    @endpoints = endpoints
    @blocks = blocks
    @auth_methods = auth_methods
    @base = base
  end

  def problems
    @problems ||= colliding + live_endpoints.flat_map { |endpoint| endpoint_problems(endpoint) } + circular
  end

  # A candidate is a pull request, so one that reads as no diff at all has
  # nothing to review and must not be saved.
  def unchanged?
    @endpoints.none? { |endpoint| endpoint_change(endpoint) } &&
      @blocks.entities.none? { |block| entity_change(block) } &&
      @auth_methods.none? { |auth_method| auth_method_change(auth_method) }
  end

  def submittable?
    problems.empty? && !unchanged?
  end

  def endpoint_change(endpoint)
    return "removed" if endpoint.removed
    return "added" if base_endpoint(endpoint).nil?

    "changed" if endpoint_diff(endpoint).any_changes?
  end

  def entity_change(block)
    return "removed" if block.removed

    base_entity = @base.entities.find { |entity| entity.identity_name == block.name }
    return "added" if base_entity.nil?

    "changed" if Diff::FromValues.new(base_entity.parsed_root, @blocks.parse(block)).any_changes?
  end

  def auth_method_change(auth_method)
    return "removed" if auth_method.removed

    base_auth_method = @base.auth_methods.find { |record| record.identity_name == auth_method.name }
    return "added" if base_auth_method.nil?
    return "changed" if base_auth_method.kind != auth_method.kind

    "changed" if DiffText::FromNotes.new(base_auth_method.note, auth_method.note).any_changes?
  end

  private

  def live_endpoints
    @live_endpoints ||= @endpoints.reject(&:removed)
  end

  def base_endpoint(endpoint)
    @base.endpoints.find { |record| record.identity_name == endpoint.identity_name }
  end

  def endpoint_diff(endpoint)
    chosen = @auth_methods.reject(&:removed).find { |auth_method| auth_method.name == endpoint.auth }
    SchemaForm::EndpointDiff.new(base_endpoint(endpoint), endpoint, @blocks, chosen)
  end

  def colliding
    live_endpoints.group_by(&:identity).each_value.select { |group| group.size > 1 }
      .map { |group| problem(group.first, "is declared twice") }
  end

  def endpoint_problems(endpoint)
    [ no_responses(endpoint), repeated_path_param(endpoint), nameless_query_param(endpoint),
      repeated_query_param(endpoint) ].compact
  end

  def no_responses(endpoint)
    problem(endpoint, "has no responses") if endpoint.responses.empty?
  end

  def repeated_path_param(endpoint)
    repeated = repeated_names(endpoint.path.scan(::Endpoint::PARAM_TOKEN).flatten)
    problem(endpoint, "repeats :#{repeated.first} in its path") if repeated.any?
  end

  def nameless_query_param(endpoint)
    problem(endpoint, "has a query param with no name") if endpoint.query_params.any? { |param| param.name.blank? }
  end

  def repeated_query_param(endpoint)
    repeated = repeated_names(endpoint.query_params.map(&:name).reject(&:blank?))
    problem(endpoint, "names the query param #{repeated.first} twice") if repeated.any?
  end

  def repeated_names(names)
    names.tally.select { |_name, count| count > 1 }.keys
  end

  def circular
    cycle = EntityReferences.new(@blocks.version.entities).cycle
    return [] if cycle.nil?

    [ Problem.new(anchor: "form-entity-#{@blocks.entities.find { |block| block.name == cycle.first }.id}",
                  subject: cycle.join(" → "), message: "reference each other in a circle") ]
  end

  def problem(endpoint, message)
    Problem.new(anchor: "form-endpoint-#{endpoint.key}", subject: endpoint.identity_name, message: message)
  end
end
