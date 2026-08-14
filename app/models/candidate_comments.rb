class CandidateComments
  EMPTY_CARD = { whole: [], lines: [] }.freeze

  LineComments = Data.define(:fresh, :outdated) do
    def by_line
      fresh.group_by(&:line)
    end
  end

  def self.for(candidate)
    return new([]) unless candidate

    new(candidate.comments.where(parent_id: nil).includes(:author, replies: :author).order(:created_at))
  end

  def initialize(roots)
    @by_anchor = {}
    @endpoint_cards = {}
    @entity_cards = {}
    @auth_method_cards = {}
    @release_notes_card = { whole: [], lines: [] }
    @response_lines = {}
    @entity_lines = {}
    @input_lines = {}
    roots.each { |comment| index(comment) }
    sort_line_buckets
  end

  def threads_for(scope, endpoint: nil, entity: nil, auth_method: nil, response_code: nil, param_name: nil, param_location: nil, part: nil)
    parts = part ? [ part ] : CommentAnchor.parts_for(scope)
    parts.flat_map do |scope_part|
      @by_anchor.fetch([ scope, endpoint&.identity_path, verb_of(endpoint), entity&.name, response_code, param_name, param_location, auth_method&.name, scope_part, nil ], [])
    end.sort_by(&:created_at)
  end

  def card_for_endpoint(endpoint)
    @endpoint_cards.fetch(endpoint_key(endpoint), EMPTY_CARD)
  end

  def card_for_entity(entity)
    @entity_cards.fetch(entity.name, EMPTY_CARD)
  end

  def card_for_auth_method(auth_method)
    @auth_method_cards.fetch(auth_method.name, EMPTY_CARD)
  end

  def sidebar_count(anchor)
    card_for_anchor(anchor).values.sum(&:size)
  end

  def response_output_lines(endpoint, response_code)
    current_output = endpoint.responses.find { |r| r.code == response_code }&.output
    by_freshness(@response_lines.fetch([ *endpoint_key(endpoint), response_code ], []), current_output)
  end

  def entity_root_lines(entity)
    by_freshness(@entity_lines.fetch(entity.name, []), entity.root)
  end

  def endpoint_input_lines(endpoint)
    by_freshness(@input_lines.fetch(endpoint_key(endpoint), []), endpoint.input)
  end

  private

  def by_freshness(comments, current_text)
    fresh, outdated = comments.partition { |comment| comment.anchor_snapshot == current_text }
    LineComments.new(fresh: fresh, outdated: outdated)
  end

  def index(comment)
    (@by_anchor[comment.anchor_key] ||= []) << comment

    case comment.scope
    when "endpoint", "response", "param"
      key = comment_endpoint_key(comment)
      into_card(@endpoint_cards, key, comment)
      if comment.scope == "response" && comment.part == "output" && comment.line
        (@response_lines[[ *key, comment.response_code ]] ||= []) << comment
      end
      if comment.scope == "endpoint" && comment.part == "input" && comment.line
        (@input_lines[key] ||= []) << comment
      end
    when "entity"
      into_card(@entity_cards, comment.entity_name, comment)
      (@entity_lines[comment.entity_name] ||= []) << comment if comment.part == "root" && comment.line
    when "auth_method"
      into_card(@auth_method_cards, comment.auth_method_name, comment)
    when "release_notes"
      @release_notes_card[:whole] << comment
    end
  end

  def into_card(cards, key, comment)
    card = (cards[key] ||= { whole: [], lines: [] })
    (comment.line ? card[:lines] : card[:whole]) << comment
  end

  def card_for_anchor(anchor)
    if anchor.scope == "release_notes"
      @release_notes_card
    elsif anchor.scope == "entity"
      @entity_cards.fetch(anchor.entity_name, EMPTY_CARD)
    elsif anchor.scope == "auth_method"
      @auth_method_cards.fetch(anchor.auth_method_name, EMPTY_CARD)
    else
      @endpoint_cards.fetch([ anchor.endpoint_identity_path, anchor.endpoint_http_verb ], EMPTY_CARD)
    end
  end

  def sort_line_buckets
    (@endpoint_cards.values + @entity_cards.values + @auth_method_cards.values).each do |card|
      card[:lines].sort_by! { |comment| [ comment.line, comment.created_at ] }
    end
    (@response_lines.values + @entity_lines.values + @input_lines.values).each do |list|
      list.sort_by! { |comment| [ comment.line, comment.created_at ] }
    end
  end

  def endpoint_key(endpoint)
    [ endpoint.identity_path, verb_of(endpoint) ]
  end

  def comment_endpoint_key(comment)
    [ Endpoint.identity_path(comment.endpoint_path), comment.endpoint_http_verb ]
  end

  def verb_of(endpoint)
    endpoint && Endpoint.http_verbs[endpoint.http_verb]
  end
end
