class CommentTarget::Param
  attr_reader :path, :http_verb, :name, :location

  def self.build(identity)
    new(path: identity[:endpoint_path], http_verb: identity[:endpoint_http_verb],
        name: identity[:param_name], location: identity[:param_location])
  end

  def initialize(path:, http_verb:, name:, location:)
    @path = path
    @http_verb = http_verb
    @name = name
    @location = location
  end

  def scope = "param"
  def parts = %w[whole]
  def required = %i[endpoint_path endpoint_http_verb param_name param_location]
end
