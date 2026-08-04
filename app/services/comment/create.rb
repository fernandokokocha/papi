class Comment::Create
  attr_reader :comment, :reopened_parent

  def initialize(candidate, comment_params, anchor_params, author: Current.user)
    @candidate = candidate
    @comment = candidate.comments.new(comment_params)
    @comment.author = author
    assign_anchor(anchor_params) if @comment.root?
  end

  def call
    return false unless @comment.save
    @reopened_parent = @comment.reply? && Comment::Reopen.new(@comment.parent).call
    true
  end

  private

  def assign_anchor(anchor_params)
    anchor = CommentAnchor.from_params(anchor_params)
    @comment.assign_attributes(anchor.to_columns)
    @comment.anchor_snapshot = anchor.current_output(@candidate.latest_version) if anchor.line
  end
end
