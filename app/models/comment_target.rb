module CommentTarget
  def self.classes
    { "candidate" => Candidate, "release_notes" => ReleaseNotes, "endpoint" => Endpoint, "entity" => Entity, "response" => Response, "param" => Param, "auth_method" => AuthMethod }
  end

  def self.parts_for(scope)
    classes.fetch(scope).build({}).parts
  end

  # Every identity column any scope can ask for. A scope's own `required` is the
  # subset it must have; the rest are the ones it must leave blank.
  def self.identity_columns
    @identity_columns ||= classes.each_value.flat_map { |klass| klass.build({}).required }.uniq
  end

  def self.build(scope, identity)
    classes[scope]&.build(identity)
  end
end
