class Comment < ApplicationRecord
  belongs_to :candidate
  belongs_to :author, class_name: "User"
  belongs_to :parent, class_name: "Comment", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  validates :body, presence: true
  validate :parent_must_be_root
  validate :reply_on_parent_candidate
  validate :anchor_valid

  def root?
    parent_id.nil?
  end

  def reply?
    !root?
  end

  def by_candidate_author?
    author_id == candidate.author_id
  end

  def anchor
    CommentAnchor.new(
      scope: scope, part: part, line: line,
      endpoint_path: endpoint_path, endpoint_http_verb: endpoint_http_verb,
      entity_name: entity_name, response_code: response_code
    )
  end

  def anchor_key
    anchor.key
  end

  private

  def parent_must_be_root
    return if parent.nil?
    errors.add(:parent, "must be a root comment") unless parent.root?
  end

  def reply_on_parent_candidate
    return if parent.nil?
    errors.add(:parent, "must be on the same candidate") unless parent.candidate_id == candidate_id
  end

  def anchor_valid
    anchor.errors.each { |column, message| errors.add(column, message) }
  end
end
