class Project < ApplicationRecord
  has_many :versions, dependent: :destroy
end
