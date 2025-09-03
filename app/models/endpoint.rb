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
  has_many :responses

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

  amoeba do
    enable
  end
end
