class Endpoint < ApplicationRecord
  VERB_TRANSLATIONS = {
    verb_get: "GET",
    verb_post: "POST",
    verb_put: "PUT",
    verb_patch: "PATCH",
    verb_delete: "DELETE"
  }

  enum :http_verb, [ :verb_get, :verb_post, :verb_put, :verb_patch, :verb_delete ]
  belongs_to :version
  belongs_to :endpoint_root, polymorphic: true

  def verb
    VERB_TRANSLATIONS[http_verb.to_sym]
  end
end
