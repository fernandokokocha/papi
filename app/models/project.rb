class Project < ApplicationRecord
  has_many :versions, dependent: :destroy
  belongs_to :group

  def latest_version
    versions.order(order: :desc).first || null_version
  end

  def null_version
    Version.new(project: self, name: "", order: 0, created_at: NullTime.new)
  end
end
