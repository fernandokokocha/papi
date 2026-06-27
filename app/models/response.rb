class Response < ApplicationRecord
  belongs_to :endpoint

  validates :code, uniqueness: { scope: :endpoint_id }

  def parsed_output
    parser = JSONSchemaParser.new(endpoint.version.entities)
    parser.parse_value(output)
  end

  def serialize
  end
end
