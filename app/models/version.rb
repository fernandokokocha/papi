class Version < ApplicationRecord
  belongs_to :project
  has_many :endpoints, dependent: :destroy
  has_many :entities, dependent: :destroy
  accepts_nested_attributes_for :endpoints # , allow_destroy: true
  accepts_nested_attributes_for :entities # , allow_destroy: true

  validates :name, uniqueness: { scope: :project_id }

  def previous
    project.versions.find_by(order: order - 1)
  end

  def next
    project.versions.find_by(order: order + 1)
  end

  def existing_endpoints_for_frontend
    endpoints.map do |endpoint|
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

  def existing_entities_for_frontend
    entities.map do |entity|
      {
        name: entity.name,
        root: entity.root.serialize
      }
    end.to_json
  end

  amoeba do
    enable
  end
end
