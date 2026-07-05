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
    return 0 unless @comment_threads_by_anchor

    verb = Endpoint.http_verbs[endpoint.http_verb]
    @comment_threads_by_anchor.sum do |(scope, path, key_verb, *), threads|
      %w[endpoint response].include?(scope) && path == endpoint.path && key_verb == verb ? threads.size : 0
    end
  end

  def entity_comment_thread_count(entity)
    return 0 unless @comment_threads_by_anchor

    @comment_threads_by_anchor.sum do |key, threads|
      key[0] == "entity" && key[3] == entity.name ? threads.size : 0
    end
  end
end
