class Candidate < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :versions
  belongs_to :base_version, class_name: "Version", foreign_key: "base_version_id", optional: true

  scope :open, -> { where(aasm_state: "open") }

  def latest_version
    versions.order(order: :desc).first || Version.null_version(project)
  end

  def to_param
    name
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
