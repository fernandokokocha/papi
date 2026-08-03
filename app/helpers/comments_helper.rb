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

  def response_line_index_map(previous_endpoint, endpoint, code, expanded:)
    return nil unless @candidate
    after = endpoint.responses.find { |r| r.code == code }
    return nil unless after

    before = previous_endpoint&.responses&.find { |r| r.code == code }
    after_value = expanded ? after.parsed_output.expand : after.parsed_output
    lines =
      if before
        before_value = expanded ? before.parsed_output.expand : before.parsed_output
        Diff::FromValues.new(before_value, after_value).after
      else
        after_value.to_diff(:added)
      end
    ExpandedLineIndex.new(lines, endpoint.version.entities).to_a
  end

  def entity_line_index_map(entity)
    return nil unless @candidate
    return nil if entity.annotation == "removed"

    lines =
      if entity.previous
        Diff::FromValues.new(entity.previous.parsed_root, entity.parsed_root).after
      else
        entity.parsed_root.to_diff(:no_change)
      end
    ExpandedLineIndex.new(lines, entity.version.entities).to_a
  end

  def response_line_pick_attr(endpoint, code, map)
    return "".html_safe if map.nil?
    line_pick_attributes(CommentAnchor.for_response_output(endpoint, code))
  end

  def entity_line_pick_attr(entity, map)
    return "".html_safe if map.nil?
    line_pick_attributes(CommentAnchor.for_entity_root(entity))
  end

  def line_index_attr(map, index)
    return "".html_safe if map.nil?
    expanded_index = map[index]
    return "".html_safe if expanded_index.nil?
    tag.attributes("data-line-index": expanded_index)
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
    params[:line_badge]&.to_sym
  end
end
