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
  belongs_to :input, polymorphic: true
  belongs_to :output, polymorphic: true

  scope :sort_by_name, -> { order([ :url, :http_verb ]) }

  def verb
    VERB_TRANSLATIONS[http_verb.to_sym]
  end

  def name
    "#{verb} #{url}"
  end

  def diff(previous_version)
    previous_endpoint = previous_version.endpoints.find_by(url: url, http_verb: http_verb)
    return nil if previous_endpoint.nil?
    Diff.new.diff(previous_endpoint.endpoint_root, endpoint_root)
  end

  def page_url
    "#{verb}-#{url}"
  end
end
