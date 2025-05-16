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

  def changed_endpoints
    return [] unless self.previous
    next_endpoints = self.previous.endpoints
    endpoints.reject { |e| next_endpoints.none? { |ne| ne.name == e.name } }
  end

  amoeba do
    enable
  end
end
