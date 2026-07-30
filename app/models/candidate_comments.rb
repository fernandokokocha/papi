class CandidateComments
  EMPTY_CARD = { whole: [], lines: [] }.freeze

  def self.for(candidate)
    return new([]) unless candidate

    new(candidate.comments.where(parent_id: nil).includes(:author, replies: :author).order(:created_at))
  end

  def initialize(roots)
    @by_anchor = {}
    @endpoint_cards = {}
    @entity_cards = {}
    @response_lines = {}
    @entity_lines = {}
    roots.each { |comment| index(comment) }
    sort_line_buckets
  end

  def threads_for(scope, endpoint: nil, entity: nil, response_code: nil, part: nil)
    parts = part ? [ part ] : CommentAnchor.parts_for(scope)
    parts.flat_map do |scope_part|
      @by_anchor.fetch([ scope, endpoint&.path, verb_of(endpoint), entity&.name, response_code, scope_part, nil ], [])
    end.sort_by(&:created_at)
  end

  def card_for_endpoint(endpoint)
    @endpoint_cards.fetch(endpoint_key(endpoint), EMPTY_CARD)
  end

  def card_for_entity(entity)
    @entity_cards.fetch(entity.name, EMPTY_CARD)
  end

  def sidebar_count(anchor)
    card_for_anchor(anchor).values.sum(&:size)
  end

  def response_output_lines(endpoint, response_code)
    @response_lines.fetch([ *endpoint_key(endpoint), response_code ], [])
  end

  def entity_root_lines(entity)
    @entity_lines.fetch(entity.name, [])
  end

  private

  def index(comment)
    (@by_anchor[comment.anchor_key] ||= []) << comment

    case comment.scope
    when "endpoint", "response"
      into_card(@endpoint_cards, [ comment.endpoint_path, comment.endpoint_http_verb ], comment)
      if comment.scope == "response" && comment.part == "output" && comment.line
        (@response_lines[[ comment.endpoint_path, comment.endpoint_http_verb, comment.response_code ]] ||= []) << comment
      end
    when "entity"
      into_card(@entity_cards, comment.entity_name, comment)
      (@entity_lines[comment.entity_name] ||= []) << comment if comment.part == "root" && comment.line
    end
  end

  def into_card(cards, key, comment)
    card = (cards[key] ||= { whole: [], lines: [] })
    (comment.line ? card[:lines] : card[:whole]) << comment
  end

  def card_for_anchor(anchor)
    if anchor.scope == "entity"
      @entity_cards.fetch(anchor.entity_name, EMPTY_CARD)
    else
      @endpoint_cards.fetch([ anchor.endpoint_path, anchor.endpoint_http_verb ], EMPTY_CARD)
    end
  end

  def sort_line_buckets
    (@endpoint_cards.values + @entity_cards.values).each do |card|
      card[:lines].sort_by! { |comment| [ comment.line, comment.created_at ] }
    end
    (@response_lines.values + @entity_lines.values).each do |list|
      list.sort_by! { |comment| [ comment.line, comment.created_at ] }
    end
  end

  def endpoint_key(endpoint)
    [ endpoint.path, verb_of(endpoint) ]
  end

  def verb_of(endpoint)
    endpoint && Endpoint.http_verbs[endpoint.http_verb]
  end
end
