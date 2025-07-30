class Project < ApplicationRecord
  has_many :versions, dependent: :destroy
  has_many :candidates, dependent: :destroy
  belongs_to :group

  validates :name, uniqueness: { scope: :group_id }

  def latest_version
    versions.order(order: :desc).first || null_version
  end

  def latest_candidate
    candidates.order(order: :desc).first || null_candidate
  end

  def null_version
    Version.new(project: self, name: "", order: 0, created_at: NullTime.new)
  end

  def null_candidate
    Candidate.new(project: self, name: "", order: 0, created_at: NullTime.new)
  end

  def can_create_candidate?
    candidates.open.empty?
  end
end
