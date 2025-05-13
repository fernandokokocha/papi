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
    endpoints.reject { |e| next_endpoints.any? { |ne| ne.url == e.url && ne.http_verb == e.http_verb } }
  end

  amoeba do
    enable
  end
end
