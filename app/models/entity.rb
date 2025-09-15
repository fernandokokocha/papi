class Entity < ApplicationRecord
  attr_accessor :annotation
  attr_accessor :previous

  belongs_to :version

  validates :name, uniqueness: { scope: :version_id }

  scope :sort_by_name, -> { order([ :name ]) }

  def parsed_root
    parser = JSONSchemaParser.new
    parser.parse_value(root)
  end
end
