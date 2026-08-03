class Comment::Reopen
  def initialize(comment)
    @comment = comment
  end

  def call
    return false unless @comment.resolved?
    @comment.update_columns(resolved_at: nil, resolved_by_id: nil)
    true
  end
end
