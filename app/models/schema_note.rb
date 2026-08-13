require "json"

# Addresses one node inside its notable's schema, using the path the React
# editor already threads through every node: object attributes by name, an
# array element as null, a one-of branch by index. Stored as JSON so both
# sides read it with no grammar of their own.
class SchemaNote < ApplicationRecord
  belongs_to :notable, polymorphic: true

  validates :body, presence: true
  validates :path, presence: true, uniqueness: { scope: [ :notable_type, :notable_id ] }
  validate :path_is_a_json_array

  # Notes are spec content, so a reworded one is a change like any other.
  def self.differ?(before, after)
    bodies_by_path(before) != bodies_by_path(after)
  end

  def self.bodies_by_path(notes)
    notes.to_h { |note| [ note.path, note.body ] }
  end

  def self.serialize_path(segments)
    JSON.generate(segments)
  end

  def segments
    JSON.parse(path)
  end

  private

  def path_is_a_json_array
    return if path.blank?
    errors.add(:path, "is not a JSON array") unless JSON.parse(path).is_a?(Array)
  rescue JSON::ParserError
    errors.add(:path, "is not valid JSON")
  end
end
