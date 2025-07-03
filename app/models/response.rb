class Response < ApplicationRecord
  belongs_to :endpoint

  validates :code, uniqueness: { scope: :endpoint_id }
end
