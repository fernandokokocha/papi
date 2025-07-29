class Candidate < ApplicationRecord
  include AASM

  belongs_to :project
  has_many :versions

  def latest_version
    versions.order(order: :desc).first || Version.null_version(project)
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
