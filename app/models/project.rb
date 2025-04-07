class Project < ApplicationRecord
  has_many :versions, dependent: :destroy

  def latest_version
    versions.order(order: :desc).first
  end
end
