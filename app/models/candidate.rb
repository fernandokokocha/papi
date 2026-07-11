class Candidate < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :versions
  has_many :comments
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

  def comment_threads_by_anchor
    comments.includes(:author, replies: :author)
      .select(&:root?)
      .sort_by(&:created_at)
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
