class Version < ApplicationRecord
  belongs_to :project, optional: true
  belongs_to :candidate
  has_many :endpoints, -> { order([ :path, :http_verb ]) }, dependent: :destroy
  has_many :entities, -> { order([ :name ]) }, dependent: :destroy
  accepts_nested_attributes_for :endpoints
  accepts_nested_attributes_for :entities

  validates :name, uniqueness: { scope: :project_id }
  validate :endpoints_are_distinct_to_a_client
  validate :entity_references_are_acyclic

  def self.null_version(project)
    self.new(
      project: project,
      name: "",
      order: -1,
      created_at: NullTime.new
    )
  end

  def previous
    return Version.null_version(project) unless project
    project.versions.find_by(order: order - 1) || Version.null_version(project)
  end

  def next
    project.versions.find_by(order: order + 1)
  end

  def earlier_versions
    project.versions.where(self.class.arel_table[:order].lt(order)).order(order: :desc)
  end

  def earlier_version!(name)
    earlier_versions.find_by!(name: name)
  end

  def existing_endpoints_for_frontend
    endpoints.map do |endpoint|
      {
        http_verb: endpoint.http_verb,
        verb: endpoint.verb,
        path: endpoint.path,
        params: endpoint.path_params.map { |param| { name: param.name, kind: param.kind } },
        query_params: endpoint.query_params.map { |param| { name: param.name, kind: param.kind, required: param.required } },
        note: endpoint.note,
        input: endpoint.input,
        responses: endpoint.responses.sort_by(&:code).map { |r| { code: r.code, note: r.note, output: r.output } }
      }
    end.to_json
  end

  def existing_entities_for_frontend
    entities.map do |entity|
      {
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

  private

  def endpoints_are_distinct_to_a_client
    collisions = endpoints.map(&:identity_name).tally.select { |_name, count| count > 1 }.keys
    return if collisions.empty?

    errors.add(:endpoints, "collide: #{collisions.join(', ')}")
  end

  def entity_references_are_acyclic
    cycle = EntityReferences.new(entities).cycle
    return if cycle.nil?

    errors.add(:entities, "reference each other in a circle: #{cycle.join(' → ')}")
  end
end
