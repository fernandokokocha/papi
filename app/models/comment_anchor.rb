require "digest/md5"

class CommentAnchor
  # One row per scope: which parts are legal, and which identity columns pin it down.
  RULES = {
    "candidate" => { parts: %w[whole],             identity: %i[] },
    "endpoint"  => { parts: %w[whole note],        identity: %i[endpoint_path endpoint_http_verb] },
    "entity"    => { parts: %w[whole root],        identity: %i[entity_name] },
    "response"  => { parts: %w[whole note output], identity: %i[endpoint_path endpoint_http_verb response_code] }
  }.freeze

  IDENTITY_COLUMNS = %i[endpoint_path endpoint_http_verb entity_name response_code].freeze
  LINE_PARTS = %w[note output root].freeze

  attr_reader :scope, :part, :line,
              :endpoint_path, :endpoint_http_verb, :entity_name, :response_code

  def initialize(scope:, part:, line: nil,
                 endpoint_path: nil, endpoint_http_verb: nil,
                 entity_name: nil, response_code: nil)
    @scope = scope
    @part = part
    @line = line
    @endpoint_path = endpoint_path
    @endpoint_http_verb = endpoint_http_verb
    @entity_name = entity_name
    @response_code = response_code
  end

  def key
    [ scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line ]
  end

  def errors
    rule = RULES[scope]
    return [ [ :scope, "is not a valid scope" ] ] unless rule

    result = []
    result << [ :part, "is not valid for scope #{scope}" ] unless rule[:parts].include?(part)

    rule[:identity].each do |col|
      result << [ col, "is required for scope #{scope}" ] if public_send(col).blank?
    end
    (IDENTITY_COLUMNS - rule[:identity]).each do |col|
      result << [ col, "must be blank for scope #{scope}" ] if public_send(col).present?
    end

    result << [ :line, "requires a text part" ] if line.present? && !LINE_PARTS.include?(part)
    result
  end

  def self.from_params(params)
    new(
      scope: (params[:scope] || params["scope"]).presence || "candidate",
      part: (params[:part] || params["part"]).presence || "whole",
      endpoint_path: (params[:endpoint_path] || params["endpoint_path"]).presence,
      endpoint_http_verb: (params[:endpoint_http_verb] || params["endpoint_http_verb"]).presence&.to_i,
      entity_name: (params[:entity_name] || params["entity_name"]).presence,
      response_code: (params[:response_code] || params["response_code"]).presence
    )
  end

  def to_columns
    {
      scope: scope, part: part, line: line,
      endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
      entity_name: entity_name, response_code: response_code
    }
  end

  def dom_id
    "comment_anchor_#{Digest::MD5.hexdigest(key.map(&:to_s).join("\x1f"))}"
  end
end
