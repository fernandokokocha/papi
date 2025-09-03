class Entity < ApplicationRecord
  belongs_to :version

  validates :name, uniqueness: { scope: :version_id }

  scope :sort_by_name, -> { order([ :name ]) }

  def root
    parser = JSONSchemaParser.new(version.entities)
    parser.parse_value(original_root)
  end
end
