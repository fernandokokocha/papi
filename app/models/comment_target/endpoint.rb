class CommentTarget::Endpoint
  attr_reader :path, :http_verb

  def self.build(identity) = new(path: identity[:endpoint_path], http_verb: identity[:endpoint_http_verb])

  def initialize(path:, http_verb:)
    @path = path
    @http_verb = http_verb
  end

  def scope = "endpoint"
  def kind = :endpoint
  def parts = %w[whole note input auth]
  def required = %i[endpoint_path endpoint_http_verb]

  def record(version)
    Endpoint.find_by_identity(version, path, http_verb)
  end
end
