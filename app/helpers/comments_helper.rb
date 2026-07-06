module CommentsHelper
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
    comment_sidebar_count(endpoint_sidebar_anchor(endpoint))
  end

  def entity_comment_thread_count(entity)
    comment_sidebar_count(entity_sidebar_anchor(entity))
  end

  # The whole-endpoint / whole-entity anchor a sidebar badge counts against.
  # Its dom_id keys the badge container so a live create can target it.
  def endpoint_sidebar_anchor(endpoint)
    CommentAnchor.new(scope: "endpoint", part: "whole",
                      endpoint_path: endpoint.path, endpoint_http_verb: Endpoint.http_verbs[endpoint.http_verb])
  end

  def entity_sidebar_anchor(entity)
    CommentAnchor.new(scope: "entity", part: "whole", entity_name: entity.name)
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
end
