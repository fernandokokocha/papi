class CommentTarget::Entity
  attr_reader :name

  def self.build(identity) = new(name: identity[:entity_name])

  def initialize(name:)
    @name = name
  end

  def scope = "entity"
  def parts = %w[whole root]
  def required = %i[entity_name]
  def label_segments = [ name ]

  def record(version)
    version.entities.find_by(name: name)
  end
end
