class Comment < ApplicationRecord
  belongs_to :candidate
  belongs_to :author, class_name: "User"
  belongs_to :parent, class_name: "Comment", optional: true
  belongs_to :resolved_by, class_name: "User", optional: true
  has_many :replies, class_name: "Comment", foreign_key: :parent_id, dependent: :destroy

  ANCHOR_ATTRIBUTES = %w[scope part line endpoint_path endpoint_http_verb entity_name response_code anchor_snapshot].freeze

  before_validation :inherit_parent_anchor, if: :parent
  after_create :reopen_parent, if: :reply?

  validates :body, presence: true
  validates :anchor_snapshot, presence: true, if: :line
  validate :parent_must_be_root
  validate :reply_on_parent_candidate
  validate :anchor_valid
  validate :reply_not_resolved

  def root?
    parent_id.nil?
  end

  def reply?
    !root?
  end

  def resolved?
    resolved_at.present?
  end

  def reopened_parent?
    @reopened_parent == true
  end

  def by_candidate_author?
    author_id == candidate.author_id
  end

  def anchor
    CommentAnchor.new(
      scope: scope, part: part, line: line, snapshot: anchor_snapshot,
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

  def inherit_parent_anchor
    assign_attributes(parent.slice(*ANCHOR_ATTRIBUTES))
  end

  def reply_not_resolved
    return unless reply?
    errors.add(:resolved_at, "cannot be set on a reply") if resolved_at.present? || resolved_by_id.present?
  end

  def reopen_parent
    return unless parent&.resolved?
    parent.update_columns(resolved_at: nil, resolved_by_id: nil)
    @reopened_parent = true
  end
end
