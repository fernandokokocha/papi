class CommentTarget::AuthMethod
  attr_reader :name

  def self.build(identity) = new(name: identity[:auth_method_name])

  def initialize(name:)
    @name = name
  end

  def scope = "auth_method"
  def parts = %w[whole note]
  def required = %i[auth_method_name]
  def label_segments = [ name ]

  def record(version)
    version.auth_methods.find_by(name: name)
  end
end
