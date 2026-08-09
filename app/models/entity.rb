class Entity < ApplicationRecord
  attr_accessor :annotation
  attr_accessor :previous

  belongs_to :version

  validates :name, uniqueness: { scope: :version_id }

  scope :sort_by_name, -> { order([ :name ]) }

  def parsed_root(expanded: false)
    parser = JSONSchemaParser.new(version.entities)
    value = parser.parse_value(root)
    expanded ? value.expand : value
  end

  def to_lines
    parsed_root.to_diff(:no_change).lines
  end

  def sort_name
    name
  end

  def identity_name
    name
  end

  def differs_from?(previous)
    Diff::FromValues.new(previous.parsed_root, parsed_root).any_changes?
  end
end
