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

  def next_version_order
    max_version = versions.maximum(:order) || 0
    max_version + 1
  end

  def next_version_name
    "v#{next_version_order}"
  end

  def to_param
    name
  end
end
