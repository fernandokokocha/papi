class History
  Milestone = Struct.new(:version, :kind, :before, :after, keyword_init: true)

  def self.for_endpoint(project, endpoint)
    http_verb = Endpoint.http_verbs[endpoint.http_verb]
    new(project) { |version| Endpoint.find_by_identity(version, endpoint.path, http_verb) }
  end

  def self.for_entity(project, entity)
    new(project) { |version| version.entities.find_by(name: entity.name) }
  end

  def initialize(project, &resolve)
    @project = project
    @resolve = resolve
  end

  # A milestone is diffed against the version that last touched the thing, not
  # against its immediate predecessor: the versions in between left it alone, so
  # they carry the same value, and naming the one that moved it is what keeps the
  # page free of versions with nothing to say.
  def milestones
    reference = nil

    @project.versions.order(:order).each_with_object([]) do |version, list|
      current = @resolve.call(version)

      if current.nil?
        list << Milestone.new(version: version, kind: :removed, before: reference) if reference
        reference = nil
      elsif reference.nil?
        list << Milestone.new(version: version, kind: :added, after: current)
        reference = current
      elsif current.differs_from?(reference)
        list << Milestone.new(version: version, kind: :changed, before: reference, after: current)
        reference = current
      end
    end.reverse
  end
end
