require "digest/md5"

class CommentAnchor
  IDENTITY_COLUMNS = %i[endpoint_path endpoint_http_verb entity_name response_code].freeze
  LINE_PARTS = %w[note output root input].freeze
  private_constant :IDENTITY_COLUMNS, :LINE_PARTS

  def self.parts_for(scope)
    CommentTarget.parts_for(scope)
  end

  attr_reader :target, :part, :line

  def initialize(scope:, part:, line: nil,
                 endpoint_path: nil, endpoint_http_verb: nil,
                 entity_name: nil, response_code: nil)
    @identity = { endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
                  entity_name: entity_name, response_code: response_code }
    @scope = scope
    @target = CommentTarget.build(scope, @identity)
    @part = part
    @line = line
  end

  def scope = @scope
  def endpoint_path = @identity[:endpoint_path]
  def endpoint_http_verb = @identity[:endpoint_http_verb]
  def entity_name = @identity[:entity_name]
  def response_code = @identity[:response_code]

  def key
    [ scope, endpoint_path, endpoint_http_verb, entity_name, response_code, part, line ]
  end

  def errors
    return [ [ :scope, "is not a valid scope" ] ] unless target

    result = []
    result << [ :part, "is not valid for scope #{scope}" ] unless target.parts.include?(part)

    target.required.each do |column|
      result << [ column, "is required for scope #{scope}" ] if @identity[column].blank?
    end
    (IDENTITY_COLUMNS - target.required).each do |column|
      result << [ column, "must be blank for scope #{scope}" ] if @identity[column].present?
    end

    result << [ :line, "requires a text part" ] if line.present? && !LINE_PARTS.include?(part)
    result
  end

  def self.from_params(params)
    new(
      scope: (params[:scope] || params["scope"]).presence || "candidate",
      part: (params[:part] || params["part"]).presence || "whole",
      line: (params[:line] || params["line"]).presence&.to_i,
      endpoint_path: (params[:endpoint_path] || params["endpoint_path"]).presence,
      endpoint_http_verb: (params[:endpoint_http_verb] || params["endpoint_http_verb"]).presence&.to_i,
      entity_name: (params[:entity_name] || params["entity_name"]).presence,
      response_code: (params[:response_code] || params["response_code"]).presence
    )
  end

  def self.for_candidate
    new(scope: "candidate", part: "whole")
  end

  def self.for_endpoint(endpoint)
    new(scope: "endpoint", part: "whole",
        endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb])
  end

  def self.for_entity(entity)
    new(scope: "entity", part: "whole", entity_name: entity.name)
  end

  def self.for_response_output(endpoint, code)
    new(scope: "response", part: "output",
        endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb],
        response_code: code)
  end

  def self.for_entity_root(entity)
    new(scope: "entity", part: "root", entity_name: entity.name)
  end

  def self.for_endpoint_input(endpoint)
    new(scope: "endpoint", part: "input",
        endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb])
  end

  def self.sidebar_for(comment)
    if comment.scope == "entity"
      new(scope: "entity", part: "whole", entity_name: comment.entity_name)
    else
      new(scope: "endpoint", part: "whole",
          endpoint_path: comment.endpoint_path, endpoint_http_verb: comment.endpoint_http_verb)
    end
  end

  def to_columns
    {
      scope: scope, part: part, line: line,
      endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
      entity_name: entity_name, response_code: response_code
    }
  end

  def without_line
    self.class.new(scope: scope, part: part,
                   endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
                   entity_name: entity_name, response_code: response_code)
  end

  def current_output(version)
    case part
    when "output" then target.record(version).output
    when "root"   then target.record(version).root
    when "input"  then target.record(version).input
    end
  end

  def dom_id
    "comment_anchor_#{Digest::MD5.hexdigest(key.map(&:to_s).join("\x1f"))}"
  end

  def label
    segments = target.label_segments
    segments += [ part ] unless part == "whole"
    head = segments.join(" → ")
    line ? "#{head} · line #{line}" : head
  end

  def kind
    return :line if line
    return :note if part == "note"
    return :input if part == "input"
    case scope
    when "endpoint" then :endpoint
    when "entity"   then :entity
    when "response" then :response
    else :conversation
    end
  end
end
