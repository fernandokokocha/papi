class Comparison
  def self.for_version(version, base_name)
    new(base_name.blank? ? version.previous : version.earlier_version!(base_name), version)
  end

  def self.for_candidate(candidate)
    new(candidate.base_version || Version.null_version(candidate.project), candidate.proposed_version)
  end

  attr_reader :before, :after

  def initialize(before, after)
    @before = before
    @after = after
  end

  def release_notes?
    before.release_notes.present? || after.release_notes.present?
  end

  def endpoints
    @endpoints ||= CategorizeByName.new(before.endpoints, after.endpoints).call
  end

  def entities
    @entities ||= CategorizeByName.new(before.entities, after.entities).call
  end

  def auth_methods
    @auth_methods ||= CategorizeByName.new(before.auth_methods, after.auth_methods).call
  end
end
