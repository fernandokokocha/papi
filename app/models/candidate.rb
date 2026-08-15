class Candidate < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :versions
  has_many :comments
  has_many :approvals, dependent: :destroy
  has_many :approvers, through: :approvals, source: :user
  belongs_to :base_version, class_name: "Version", foreign_key: "base_version_id", optional: true
  belongs_to :author, class_name: "User", optional: true
  belongs_to :decided_by, class_name: "User", optional: true

  scope :open, -> { where(aasm_state: "open") }

  def latest_version
    versions.order(order: :desc).first || Version.null_version(project)
  end

  def promoted_version
    return nil unless merged?
    versions.max_by(&:order)
  end

  def to_param
    name
  end

  def approved_by?(user)
    approvals.any? { |approval| approval.user_id == user.id }
  end

  def comment_threads_by_anchor
    comments.where(parent_id: nil)
      .includes(:author, replies: :author)
      .order(:created_at)
      .group_by(&:anchor_key)
  end

  aasm column: "aasm_state" do
    state :open, initial: true
    state :merged
    state :rejected

    event :merge do
      transitions from: :open, to: :merged
    end

    event :reject do
      transitions from: :open, to: :rejected
    end
  end
end
