class Project < ApplicationRecord
  has_many :versions, dependent: :destroy
  belongs_to :group

  def latest_version
    versions.order(order: :desc).first
  end
end
