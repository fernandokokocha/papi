module CommentsHelper
  # Per-kind card wash, rail, and chip — complete literal class strings so
  # Tailwind sees them. Kinds echo the app's card colors (endpoint sky, entity
  # violet) plus non-semantic hues; all clear of the red / green / amber that
  # already mean removed / added / changed (fuchsia, not pink, so response
  # never reads as red).
  KIND_STYLES = {
    line:         { bg: "bg-indigo-50/60",  rail: "border-l-indigo-500",  chip: "bg-indigo-100 text-indigo-700 border-indigo-200" },
    response:     { bg: "bg-fuchsia-50/60", rail: "border-l-fuchsia-500", chip: "bg-fuchsia-100 text-fuchsia-700 border-fuchsia-200" },
    note:         { bg: "bg-cyan-50/60",    rail: "border-l-cyan-500",    chip: "bg-cyan-100 text-cyan-700 border-cyan-200" },
    endpoint:     { bg: "bg-sky-50/60",     rail: "border-l-sky-600",     chip: "bg-sky-100 text-sky-700 border-sky-200" },
    entity:       { bg: "bg-violet-50/60",  rail: "border-l-violet-600",  chip: "bg-violet-100 text-violet-700 border-violet-200" },
    conversation: { bg: "bg-blue-50/60",    rail: "border-l-blue-600",    chip: "bg-blue-100 text-blue-700 border-blue-200" }
  }.freeze

  def comment_kind_bg(kind)
    KIND_STYLES.fetch(kind)[:bg]
  end

  def comment_kind_rail(kind)
    KIND_STYLES.fetch(kind)[:rail]
  end

  def comment_kind_chip(kind)
    KIND_STYLES.fetch(kind)[:chip]
  end

  # Root comment threads pinned to the given target, across all of the
  # scope's valid parts (line-anchored threads are excluded; they render
  # elsewhere from Stage 6 on). Returns [] outside candidate-page context.
  def comment_threads_for(scope, endpoint: nil, entity: nil, response_code: nil, part: nil)
    return [] unless @comment_threads_by_anchor

    parts = part ? [ part ] : CommentAnchor::RULES.fetch(scope)[:parts]
    parts.flat_map do |p|
      key = CommentAnchor.new(
        scope: scope, part: p,
        endpoint_path: endpoint&.path,
        endpoint_http_verb: endpoint && Endpoint.http_verbs[endpoint.http_verb],
        entity_name: entity&.name,
        response_code: response_code
      ).key
      @comment_threads_by_anchor.fetch(key, [])
    end.sort_by(&:created_at)
  end

  def endpoint_comment_thread_count(endpoint)
    comment_sidebar_count(CommentAnchor.for_endpoint(endpoint))
  end

  def entity_comment_thread_count(entity)
    comment_sidebar_count(CommentAnchor.for_entity(entity))
  end

  def sidebar_count_dom_id(anchor)
    "sidebar_count_#{anchor.dom_id}"
  end

  # Threads counted for a sidebar badge: all endpoint + response threads sharing
  # the endpoint's identity, or all threads for an entity. 0 outside candidate
  # context. Drives both the initial render and the live Turbo update on create.
  def comment_sidebar_count(anchor)
    return 0 unless @comment_threads_by_anchor

    if anchor.scope == "entity"
      @comment_threads_by_anchor.sum { |key, threads| key[0] == "entity" && key[3] == anchor.entity_name ? threads.size : 0 }
    else
      @comment_threads_by_anchor.sum do |(scope, path, verb, *), threads|
        %w[endpoint response].include?(scope) && path == anchor.endpoint_path && verb == anchor.endpoint_http_verb ? threads.size : 0
      end
    end
  end

  def comment_count_badge(count)
    return "".html_safe if count.zero?

    tag.span("💬 #{count}", class: "text-[10px] text-gray-500")
  end

  # `data-comment-region` marker for a commentable target — emitted only in
  # candidate context (@candidate present), so version pages stay affordance-free.
  def comment_region_attr(anchor)
    return "".html_safe unless @candidate
    tag.attributes("data-comment-region": anchor.dom_id)
  end

  # Output-line root threads for one response (scope response, part output, line set),
  # sorted by [line, created_at]. [] outside candidate context.
  def response_output_comments(endpoint, response_code)
    return [] unless @comment_threads_by_anchor

    verb = Endpoint.http_verbs[endpoint.http_verb]
    @comment_threads_by_anchor.flat_map do |(scope, path, v, _name, code, part, line), threads|
      next [] unless scope == "response" && part == "output" && !line.nil?
      next [] unless path == endpoint.path && v == verb && code == response_code
      threads
    end.sort_by { |c| [ c.line, c.created_at ] }
  end

  # Root-line root threads for one entity (scope entity, part root, line set).
  def entity_root_comments(entity)
    return [] unless @comment_threads_by_anchor

    @comment_threads_by_anchor.flat_map do |(scope, _path, _v, name, _code, part, line), threads|
      next [] unless scope == "entity" && part == "root" && !line.nil?
      next [] unless name == entity.name
      threads
    end.sort_by { |c| [ c.line, c.created_at ] }
  end

  # Buckets a block's line comments for placement:
  # - inline: fresh AND the block is expanded → rendered under their row (grouped by line index)
  # - collapsed: fresh but the block is collapsed → valid, just not placeable in this view
  # - outdated: anchor_snapshot != current text → rendered below with archeology detail
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

  # Whitelisted placement badge echoed from a resolve/reopen/reply form so a
  # thread re-render keeps its Inlined/Collapsed/Outdated pill (the server
  # can't recompute placement — it depends on the client's expanded state).
  def line_badge_param
    %w[inlined collapsed outdated].include?(params[:line_badge]) ? params[:line_badge].to_sym : nil
  end
end
