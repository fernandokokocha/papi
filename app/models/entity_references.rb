class EntityReferences
  def initialize(entities)
    @edges = entities.reject { |entity| entity.root.blank? }
      .to_h { |entity| [ entity.name, entity.parsed_root.entity_names.uniq ] }
  end

  def cycle
    @settled = Set.new
    @edges.each_key do |name|
      found = walk(name, [])
      return found if found
    end
    nil
  end

  private

  def walk(name, path)
    return path.drop(path.index(name)) + [ name ] if path.include?(name)
    return nil if @settled.include?(name)

    @edges.fetch(name, []).each do |referenced|
      found = walk(referenced, path + [ name ])
      return found if found
    end

    @settled << name
    nil
  end
end
