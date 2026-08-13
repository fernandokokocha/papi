class Endpoint < ApplicationRecord
  attr_accessor :annotation
  attr_accessor :previous

  VERB_TRANSLATIONS = {
    verb_get: "GET",
    verb_post: "POST",
    verb_put: "PUT",
    verb_patch: "PATCH",
    verb_delete: "DELETE"
  }

  PARAM_TOKEN = /:([A-Za-z_][A-Za-z0-9_]*)/
  PARAM_SEGMENT = /\A#{PARAM_TOKEN.source}\z/

  enum :http_verb, [ :verb_get, :verb_post, :verb_put, :verb_patch, :verb_delete ]
  belongs_to :version
  has_many :responses, dependent: :delete_all
  has_many :params, class_name: "EndpointParam", dependent: :delete_all
  has_many :schema_notes, as: :notable, dependent: :delete_all
  accepts_nested_attributes_for :schema_notes

  scope :sort_by_name, -> { order([ :path, :http_verb ]) }

  accepts_nested_attributes_for :responses
  accepts_nested_attributes_for :params

  validate :path_params_are_unique

  def self.verb_word(http_verb)
    key = http_verbs.key(http_verb)
    key && VERB_TRANSLATIONS[key.to_sym]
  end

  def verb
    VERB_TRANSLATIONS[http_verb.to_sym]
  end

  # Param names are ours, not the client's: /user/:id and /user/:user_id are one
  # endpoint. Identity erases the names so a rename reads as a change, not as a
  # removal plus an addition.
  def self.identity_path(path)
    path.gsub(PARAM_TOKEN, ":")
  end

  def identity_path
    self.class.identity_path(path)
  end

  # where() builds a fresh relation, so this never reads a stale association
  # cache — the identity itself cannot be matched in SQL.
  def self.find_by_identity(version, path, http_verb)
    identity = identity_path(path)
    version.endpoints.where(http_verb: http_verb).find { |endpoint| endpoint.identity_path == identity }
  end

  def identity_name
    "#{verb} #{identity_path}"
  end

  def name
    "#{verb} #{path}"
  end

  def sort_name
    "#{path} #{http_verb_before_type_cast}"
  end

  def page_url
    "#{verb}-#{path}"
  end

  def parsed_input(expanded: false)
    parser = JSONSchemaParser.new(version.entities)
    value = parser.parse_whole_value(input)
    expanded ? value.expand : value
  end

  def auth_method
    version.auth_methods.find_by(name: auth)
  end

  def param_names
    path.scan(PARAM_TOKEN).flatten
  end

  def path_params
    stored = params.select { |param| param.location == "path" }.index_by(&:name)
    param_names.map { |name| stored[name] || EndpointParam.new(name: name, kind: "string") }
  end

  def query_params
    params.select { |param| param.location == "query" }.sort_by(&:name)
  end

  def example_query_string
    query_params.map { |param| "#{param.name}=#{param.kind}" }.join("&")
  end

  def differs_from?(previous)
    previous.path != path ||
      DiffParams::FromParams.new(previous.path_params, path_params).any_changes? ||
      DiffParams::FromParams.new(previous.query_params, query_params).any_changes? ||
      DiffAuth::FromAuth.new(previous.auth_method, auth_method).any_changes? ||
      DiffText::FromNotes.new(previous.note, note).any_changes? ||
      SchemaNote.differ?(previous.schema_notes, schema_notes) ||
      Diff::FromValues.new(previous.parsed_input, parsed_input).any_changes? ||
      DiffResponses::FromResponses.new(previous.responses, responses).any_changes?
  end

  def self.from_version_request(request, version)
    from_request(request, version, %r{^/projects/[^/]+/versions/[^/]+})
  end

  def self.from_candidate_request(request, version)
    from_request(request, version, %r{^/projects/[^/]+/candidates/[^/]+})
  end

  # A literal path wins over a param that would also match it, so /users/me
  # keeps beating /users/:id.
  def self.from_request(request, version, prefix)
    http_verb = "verb_#{request.method.downcase}"
    requested = request.path.sub(prefix, "")
    candidates = version.endpoints.where(http_verb: http_verb)

    candidates.find { |endpoint| endpoint.path == requested } ||
      candidates.find { |endpoint| endpoint.serves?(requested) }
  end

  def serves?(requested_path)
    own = path.split("/")
    given = requested_path.split("/")
    return false unless own.size == given.size

    own.zip(given).all? do |own_segment, given_segment|
      own_segment.match?(PARAM_SEGMENT) ? given_segment.present? : own_segment == given_segment
    end
  end

  amoeba do
    enable
  end

  private

  def path_params_are_unique
    duplicates = param_names.tally.select { |_name, count| count > 1 }.keys
    return if duplicates.empty?

    errors.add(:path, "repeats #{duplicates.map { |name| ":#{name}" }.join(", ")}")
  end
end
