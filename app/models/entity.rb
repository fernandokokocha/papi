class Entity < ApplicationRecord
  belongs_to :version
  belongs_to :root, polymorphic: true

  validates :name, uniqueness: { scope: :version_id }

  scope :sort_by_name, -> { order([ :name ]) }

  def to_diff(change, indent = 0)
    Diff::Lines.new([ Diff::Line.new(name, change, indent) ])
  end
end
