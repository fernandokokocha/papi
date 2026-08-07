class EndpointParam < ApplicationRecord
  KINDS = %w[string number boolean].freeze

  belongs_to :endpoint

  validates :kind, inclusion: { in: KINDS }
end
