class Diff::EntityToEntity
  attr_accessor :before, :after

  def initialize(value1, value2, indent = 0)
    if value1.entity.name == value2.entity.name && !value1.entity.differs_from?(value2.entity)
      before = [ Diff::Line.new(value1.entity.name, :no_change, indent) ]
      after = [ Diff::Line.new(value2.entity.name, :no_change, indent) ]
    else
      before = [ Diff::Line.new(value1.entity.name, :type_changed, indent) ]
      after = [ Diff::Line.new(value2.entity.name, :type_changed, indent) ]
    end

    @before = Diff::Lines.new(before)
    @after = Diff::Lines.new(after)
  end
end
