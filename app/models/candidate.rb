class Candidate < ApplicationRecord
  belongs_to :project
  has_many :versions

  def latest_version
    versions.order(order: :desc).first
  end

  amoeba do
    enable
  end
end
