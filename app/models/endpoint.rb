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

  enum :http_verb, [ :verb_get, :verb_post, :verb_put, :verb_patch, :verb_delete ]
  belongs_to :version
  has_many :responses, dependent: :delete_all
  has_many :params, class_name: "EndpointParam", dependent: :delete_all

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

  def param_names
    path.scan(PARAM_TOKEN).flatten
  end

  def path_params
    stored = params.index_by(&:name)
    param_names.map { |name| stored[name] || EndpointParam.new(name: name, kind: "string") }
  end

  def differs_from?(previous)
    DiffParams::FromParams.new(previous.path_params, path_params).any_changes? ||
      DiffText::FromNotes.new(previous.note, note).any_changes? ||
      Diff::FromValues.new(previous.parsed_input, parsed_input).any_changes? ||
      DiffResponses::FromResponses.new(previous.responses, responses).any_changes?
  end

  def self.from_version_request(request, version)
    method = request.method
    http_verb = "verb_#{method.downcase}"

    prefix = %r{^/projects/[^/]+/versions/[^/]+}
    path = request.path.sub(prefix, "")
    Endpoint.where(http_verb: http_verb, path: path, version: version)
  end

  def self.from_candidate_request(request, version)
    method = request.method
    http_verb = "verb_#{method.downcase}"

    prefix = %r{^/projects/[^/]+/candidates/[^/]+}
    path = request.path.sub(prefix, "")
    Endpoint.where(http_verb: http_verb, path: path, version: version)
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
