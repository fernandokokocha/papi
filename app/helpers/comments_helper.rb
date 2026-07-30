module CommentsHelper
  # Complete literal class strings so Tailwind sees them. Kinds echo the app's
  # card colors (endpoint sky, entity violet) plus non-semantic hues; all clear
  # of the red / green / amber that already mean removed / added / changed
  # (fuchsia, not pink, so response never reads as red).
  KIND_STYLES = {
    line:         { label: "Line",         bg: "bg-indigo-50/60",  rail: "border-l-indigo-500",  chip: "bg-indigo-100 text-indigo-700 border-indigo-200" },
    response:     { label: "Response",     bg: "bg-fuchsia-50/60", rail: "border-l-fuchsia-500", chip: "bg-fuchsia-100 text-fuchsia-700 border-fuchsia-200" },
    note:         { label: "Note",         bg: "bg-cyan-50/60",    rail: "border-l-cyan-500",    chip: "bg-cyan-100 text-cyan-700 border-cyan-200" },
    endpoint:     { label: "Endpoint",     bg: "bg-sky-50/60",     rail: "border-l-sky-600",     chip: "bg-sky-100 text-sky-700 border-sky-200" },
    entity:       { label: "Entity",       bg: "bg-violet-50/60",  rail: "border-l-violet-600",  chip: "bg-violet-100 text-violet-700 border-violet-200" },
    conversation: { label: "Conversation", bg: "bg-blue-50/60",    rail: "border-l-blue-600",    chip: "bg-blue-100 text-blue-700 border-blue-200" }
  }.freeze

  def comment_kind_style(kind)
    KIND_STYLES.fetch(kind)
  end

  def candidate_comments
    @candidate_comments ||= CandidateComments.for(@candidate)
  end

  def sidebar_count_dom_id(anchor)
    "sidebar_count_#{anchor.dom_id}"
  end

  def comment_region_attr(anchor)
    return "".html_safe unless @candidate
    tag.attributes("data-comment-region": anchor.dom_id)
  end

  def partition_line_comments(comments, current_text, expanded:)
    inline, collapsed, outdated = [], [], []
    comments.each do |comment|
      if comment.anchor_snapshot != current_text
        outdated << comment
      elsif expanded
        inline << comment
      else
        collapsed << comment
      end
    end
    { inline: inline.group_by(&:line), collapsed: collapsed, outdated: outdated }
  end

  # Canonical-index map for one response's rendered output tree: :identity when
  # rendered expanded, an Array (rendered row → expanded-tree row) when
  # collapsed, nil when not pickable (no candidate context, or the response has
  # no current side to pin to).
  def response_line_index_map(previous_endpoint, endpoint, code, expanded:)
    return nil unless @candidate
    after = endpoint.responses.find { |r| r.code == code }
    return nil unless after
    return :identity if expanded

    before = previous_endpoint&.responses&.find { |r| r.code == code }
    if before
      rendered = Diff::FromValues.new(before.parsed_output, after.parsed_output).after
      expanded_lines = Diff::FromValues.new(before.parsed_output.expand, after.parsed_output.expand).after
    else
      rendered = after.parsed_output.to_diff(:added)
      expanded_lines = after.parsed_output.expand.to_diff(:added)
    end
    Diff::LineIndexMap.new(rendered, expanded_lines).to_a
  end

  # Entity roots don't reference entities, so their trees render expanded as-is.
  def entity_line_index_map
    @candidate ? :identity : nil
  end

  def response_line_pick_attr(endpoint, code, map)
    return "".html_safe if map.nil?
    line_pick_attributes(CommentAnchor.for_response_output(endpoint, code))
  end

  def entity_line_pick_attr(entity, map)
    return "".html_safe if map.nil?
    line_pick_attributes(CommentAnchor.for_entity_root(entity))
  end

  # data-line-index for one rendered row: its canonical expanded-tree index.
  # Blank alignment rows and non-pickable trees get nothing.
  def line_index_attr(map, index, diff_line)
    return "".html_safe if map.nil? || diff_line.change == :blank
    canonical = map == :identity ? index : map[index]
    return "".html_safe if canonical.nil?
    tag.attributes("data-line-index": canonical)
  end

  def line_pick_attributes(anchor)
    tag.attributes("data-line-pick": anchor.dom_id, "data-line-pick-label": anchor.label)
  end

  def card_comments_data(endpoints, entities)
    data = { endpoints: {}, entities: {} }

    endpoints.each do |endpoint|
      threads = candidate_comments.card_for_endpoint(endpoint)
      next if threads[:whole].empty? && threads[:lines].empty?
      data[:endpoints]["#{endpoint.http_verb} #{endpoint.path}"] = render("comments/card_comments", threads: threads)
    end
    entities.each do |entity|
      threads = candidate_comments.card_for_entity(entity)
      next if threads[:whole].empty? && threads[:lines].empty?
      data[:entities][entity.name] = render("comments/card_comments", threads: threads)
    end
    data.to_json
  end

  def line_badge_param
    %w[inlined collapsed outdated].include?(params[:line_badge]) ? params[:line_badge].to_sym : nil
  end
end
