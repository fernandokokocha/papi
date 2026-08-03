class CommentTarget::Endpoint
  attr_reader :path, :http_verb

  def self.build(identity) = new(path: identity[:endpoint_path], http_verb: identity[:endpoint_http_verb])

  def initialize(path:, http_verb:)
    @path = path
    @http_verb = http_verb
  end

  def scope = "endpoint"
  def parts = %w[whole note]
  def required = %i[endpoint_path endpoint_http_verb]
  def label_segments = [ "#{Endpoint.verb_word(http_verb)} #{path}" ]
end
