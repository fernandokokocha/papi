class Version < ApplicationRecord
  belongs_to :project
  has_many :endpoints, dependent: :destroy

  def previous
    project.versions.find_by(order: order - 1)
  end
  def next
    project.versions.find_by(order: order + 1)
  end
end
