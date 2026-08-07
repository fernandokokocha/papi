class CommentTarget::Param
  attr_reader :path, :http_verb, :name

  def self.build(identity)
    new(path: identity[:endpoint_path], http_verb: identity[:endpoint_http_verb], name: identity[:param_name])
  end

  def initialize(path:, http_verb:, name:)
    @path = path
    @http_verb = http_verb
    @name = name
  end

  def scope = "param"
  def parts = %w[whole]
  def required = %i[endpoint_path endpoint_http_verb param_name]
  def label_segments = [ "#{Endpoint.verb_word(http_verb)} #{path}", ":#{name}" ]
end
