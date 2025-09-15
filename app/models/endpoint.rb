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

  enum :http_verb, [ :verb_get, :verb_post, :verb_put, :verb_patch, :verb_delete ]
  belongs_to :version
  has_many :responses, dependent: :delete_all

  scope :sort_by_name, -> { order([ :path, :http_verb ]) }

  accepts_nested_attributes_for :responses

  def verb
    VERB_TRANSLATIONS[http_verb.to_sym]
  end

  def name
    "#{verb} #{path}"
  end

  def sort_name
    "#{path} #{http_verb} "
  end

  def page_url
    "#{verb}-#{path}"
  end

  def parsed_output
    parser = JSONSchemaParser.new(version.entities)
    parser.parse_value(output)
  end

  def parsed_output_error
    parser = JSONSchemaParser.new(version.entities)
    parser.parse_value(output_error)
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
end
