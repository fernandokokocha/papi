class Version < ApplicationRecord
  belongs_to :project
  has_many :endpoints

  def previous
    project.versions.find_by(order: order - 1)
  end
  def next
    project.versions.find_by(order: order + 1)
  end
end
