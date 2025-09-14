class Version < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :candidate
  has_many :endpoints, -> { order([ :path, :http_verb ]) }, dependent: :destroy
  has_many :entities, -> { order([ :name ]) }, dependent: :destroy
  accepts_nested_attributes_for :endpoints
  accepts_nested_attributes_for :entities

  validates :name, uniqueness: { scope: :project_id }

  def self.null_version(project)
    self.new(
      project: project,
      name: "",
      order: -1
    )
  end

  def previous
    return Version.null_version(project) unless project
    project.versions.find_by(order: order - 1) || Version.null_version(project)
  end

  def next
    project.versions.find_by(order: order + 1)
  end

  def existing_endpoints_for_frontend
    endpoints.map do |endpoint|
      {
        http_verb: endpoint.http_verb,
        verb: endpoint.verb,
        path: endpoint.path,
        output: endpoint.output,
        output_error: endpoint.output_error,
        note: endpoint.note,
        responses: endpoint.responses.sort_by(&:code).map { |r| { code: r.code, note: r.note } }
      }
    end.to_json
  end

  def existing_entities_for_frontend
    entities.map do |entity|
      {
        id: entity.id,
        name: entity.name,
        root: entity.root
      }
    end.to_json
  end

  def to_param
    name
  end

  amoeba do
    enable
  end
end
