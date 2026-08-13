class Response < ApplicationRecord
  belongs_to :endpoint
  has_many :schema_notes, as: :notable, dependent: :delete_all
  accepts_nested_attributes_for :schema_notes

  amoeba do
    enable
  end

  validates :code, uniqueness: { scope: :endpoint_id }

  def parsed_output
    parser = JSONSchemaParser.new(endpoint.version.entities)
    parser.parse_whole_value(output)
  end

  def serialize
  end
end
