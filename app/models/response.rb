class Response < ApplicationRecord
  belongs_to :endpoint
  has_many :schema_notes, as: :notable, dependent: :delete_all
  accepts_nested_attributes_for :schema_notes

  amoeba do
    enable
  end

  validates :code, uniqueness: { scope: :endpoint_id }

  def parsed_output(expanded: false)
    parser = JSONSchemaParser.new(endpoint.version.entities)
    value = parser.parse_whole_value(output)
    expanded ? value.expand : value
  end

  def serialize
  end
end
