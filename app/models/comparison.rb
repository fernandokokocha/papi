class Comparison
  def self.for_version(version, base_name)
    new(base_name.blank? ? version.previous : version.earlier_version!(base_name), version)
  end

  def self.for_candidate(candidate)
    new(candidate.base_version || Version.null_version(candidate.project), candidate.latest_version)
  end

  def self.none
    new(Version.new, Version.new)
  end

  attr_reader :before, :after

  def initialize(before, after)
    @before = before
    @after = after
  end

  def endpoints
    @endpoints ||= Version::CategorizeByName.new(before.endpoints, after.endpoints).call
  end

  def entities
    @entities ||= Version::CategorizeByName.new(before.entities, after.entities).call
  end
end
