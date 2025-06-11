class Version < ApplicationRecord
  belongs_to :project
  has_many :endpoints, dependent: :destroy
  accepts_nested_attributes_for :endpoints # , allow_destroy: true

  def previous
    project.versions.find_by(order: order - 1)
  end

  def next
    project.versions.find_by(order: order + 1)
  end

  def removed_endpoints
    return [] unless self.next
    next_endpoints = self.next.endpoints
    endpoints.reject { |e| next_endpoints.any? { |ne| ne.name == e.name } }
  end

  def added_endpoints
    return endpoints unless self.previous
    next_endpoints = self.previous.endpoints
    endpoints.reject { |e| next_endpoints.any? { |ne| ne.name == e.name } }
  end

  def existing_endpoints
    return [] unless self.previous
    previous_endpoints = self.previous.endpoints
    ret = []
    endpoints.each do |e|
      found = previous_endpoints.find { |ne| ne.name == e.name }
      ret << [ e, found ] if found
    end

    ret
  end

  def existing_endpoints_for_frontend
    existing_endpoints.map do |endpoint, previous_endpoint|
      {
        http_verb: endpoint.http_verb,
        verb: endpoint.verb,
        url: endpoint.url,
        input: endpoint.input.serialize,
        output: endpoint.output.serialize,
        page_url: endpoint.page_url
      }
    end.to_json
  end

  amoeba do
    enable
  end
end
