class EndpointParam < ApplicationRecord
  KINDS = %w[string number boolean].freeze
  LOCATIONS = %w[path query].freeze

  belongs_to :endpoint

  validates :name, presence: true
  validates :kind, inclusion: { in: KINDS }
  validates :location, inclusion: { in: LOCATIONS }

  def label
    return ":#{name}" if location == "path"

    required ? name : "#{name}?"
  end
end
