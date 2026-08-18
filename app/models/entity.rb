class Entity < ApplicationRecord
  attr_accessor :annotation
  attr_accessor :previous

  belongs_to :version
  has_many :schema_notes, as: :notable, dependent: :delete_all
  accepts_nested_attributes_for :schema_notes

  amoeba do
    enable
  end

  validates :name, uniqueness: { scope: :version_id }

  scope :sort_by_name, -> { order([ :name ]) }

  def parsed_root(expanded: false)
    parser = JSONSchemaParser.new(version.entities)
    value = parser.parse_value(root)
    expanded ? value.expand : value
  end

  def to_lines
    parsed_root(expanded: true).to_diff(:no_change).lines
  end

  def sort_name
    name
  end

  def identity_name
    name
  end

  def differs_from?(previous)
    Diff::FromValues.new(previous.parsed_root, parsed_root).any_changes? ||
      SchemaNote.differ?(previous.schema_notes, schema_notes)
  end
end
