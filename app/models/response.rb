class Response < ApplicationRecord
  CODES = %w[
    200 201 202 203 204 205 206 207 208 226
    400 401 402 403 404 405 406 407 408 409
    410 411 412 413 414 415 416 417 418
    421 422 423 424 425 426 428 429 431 451
    500 501 502 503 504 505 506 507 508 510 511
  ].freeze

  belongs_to :endpoint
  has_many :schema_notes, as: :notable, dependent: :delete_all
  accepts_nested_attributes_for :schema_notes

  amoeba do
    enable
  end

  validates :code, uniqueness: { scope: :endpoint_id }

  def parsed_output(expanded: false)
    parser = Schema::Parser.new(endpoint.version.entities)
    value = parser.parse_whole_value(output)
    expanded ? value.expand : value
  end

  def serialize
  end
end
