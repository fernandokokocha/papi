class Version < ApplicationRecord
  belongs_to :project
  has_many :endpoints
end
