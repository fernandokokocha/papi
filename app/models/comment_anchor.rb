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
      line: (params[:line] || params["line"]).presence&.to_i,
      endpoint_path: (params[:endpoint_path] || params["endpoint_path"]).presence,
      endpoint_http_verb: (params[:endpoint_http_verb] || params["endpoint_http_verb"]).presence&.to_i,
      entity_name: (params[:entity_name] || params["entity_name"]).presence,
      response_code: (params[:response_code] || params["response_code"]).presence
    )
  end

  # Anchor factories from domain objects — the single home for the
  # http_verb → integer conversion every anchor needs.
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

  # The whole-endpoint / whole-entity anchor a comment's sidebar badge counts
  # against, rebuilt from the comment's own columns (http_verb already integer).
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

  # The same anchor without the line — the pick region every line comment's
  # DOM (compose form, below-block container) is keyed off.
  def without_line
    self.class.new(scope: scope, part: part,
                   endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
                   entity_name: entity_name, response_code: response_code)
  end

  # The whole current output of the addressed block in the given version;
  # nil when the block doesn't exist there.
  def current_output(version)
    case part
    when "output"
      version.endpoints.find_by(path: endpoint_path, http_verb: endpoint_http_verb)
        &.responses&.find_by(code: response_code)&.output
    when "root"
      version.entities.find_by(name: entity_name)&.root
    end
  end

  def dom_id
    "comment_anchor_#{Digest::MD5.hexdigest(key.map(&:to_s).join("\x1f"))}"
  end

  # e.g. "GET /users → 200 → output · line 0" / "User → root · line 0"
  def label
    segments = []
    segments << "#{verb_word} #{endpoint_path}" if endpoint_path
    segments << entity_name if entity_name
    segments << response_code if response_code
    segments << part unless part == "whole"
    head = segments.join(" → ")
    line ? "#{head} · line #{line}" : head
  end

  KIND_LABELS = {
    line: "Line", response: "Response", note: "Note",
    endpoint: "Endpoint", entity: "Entity", conversation: "Conversation"
  }.freeze

  # Coarse kind for the comment's reference chip: a line beats its part,
  # a note part beats its scope, otherwise the scope names it. Candidate-level
  # threads are the Conversation.
  def kind
    return :line if line
    return :note if part == "note"
    case scope
    when "endpoint" then :endpoint
    when "entity"   then :entity
    when "response" then :response
    else :conversation
    end
  end

  def kind_label
    KIND_LABELS.fetch(kind)
  end

  private

  def verb_word
    key = Endpoint.http_verbs.key(endpoint_http_verb)
    key && Endpoint::VERB_TRANSLATIONS[key.to_sym]
  end
end
