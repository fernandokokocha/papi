class CommentTarget::Response
  attr_reader :path, :http_verb, :code

  def self.build(identity)
    new(path: identity[:endpoint_path], http_verb: identity[:endpoint_http_verb], code: identity[:response_code])
  end

  def initialize(path:, http_verb:, code:)
    @path = path
    @http_verb = http_verb
    @code = code
  end

  def scope = "response"
  def parts = %w[whole note output]
  def required = %i[endpoint_path endpoint_http_verb response_code]
  def label_segments = [ "#{Endpoint.verb_word(http_verb)} #{path}", code ]

  def record(version)
    Endpoint.find_by_identity(version, path, http_verb).responses.find_by(code: code)
  end
end
