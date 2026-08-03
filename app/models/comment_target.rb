module CommentTarget
  def self.classes
    { "candidate" => Candidate, "endpoint" => Endpoint, "entity" => Entity, "response" => Response }
  end

  def self.parts_for(scope)
    classes.fetch(scope).build({}).parts
  end

  def self.build(scope, identity)
    classes[scope]&.build(identity)
  end
end
