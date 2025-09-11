class Endpoint < ApplicationRecord
  VERB_TRANSLATIONS = {
    verb_get: "GET",
    verb_post: "POST",
    verb_put: "PUT",
    verb_patch: "PATCH",
    verb_delete: "DELETE"
  }

  enum :http_verb, [ :verb_get, :verb_post, :verb_put, :verb_patch, :verb_delete ]
  enum :auth, [ :no_auth, :bearer ]
  belongs_to :version
  has_many :responses, dependent: :delete_all

  scope :sort_by_name, -> { order([ :url, :http_verb ]) }

  accepts_nested_attributes_for :responses

  def verb
    VERB_TRANSLATIONS[http_verb.to_sym]
  end

  def name
    "#{verb} #{url}"
  end

  def page_url
    "#{verb}-#{url}"
  end

  def input
    parser = JSONSchemaParser.new(version.entities)
    parser.parse_value(original_input_string)
  end

  def output
    parser = JSONSchemaParser.new(version.entities)
    parser.parse_value(original_output_string)
  end

  def self.from_version_request(request, version)
    method = request.method
    http_verb = "verb_#{method.downcase}"

    prefix = %r{^/projects/[^/]+/versions/[^/]+}
    url = request.path.sub(prefix, "")
    Endpoint.where(http_verb: http_verb, url: url, version: version)
  end

  def self.from_candidate_request(request, version)
    method = request.method
    http_verb = "verb_#{method.downcase}"

    prefix = %r{^/projects/[^/]+/candidates/[^/]+}
    url = request.path.sub(prefix, "")
    Endpoint.where(http_verb: http_verb, url: url, version: version)
  end

  amoeba do
    enable
  end
end
