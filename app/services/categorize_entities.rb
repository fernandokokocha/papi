class CategorizeEntities
  def initialize(previous_version, version)
    @previous_version = previous_version
    @version = version
  end

  def call
    unless @version
      return {
        existing: [],
        added: [],
        removed: []
      }
    end

    entities = @version.entities.sort_by_name

    unless @previous_version
      return {
        existing: [],
        added: entities,
        removed: []
      }
    end

    ret = {
      existing: [],
      added: [],
      removed: []
    }

    entities.each do |e|
      found = @previous_version.entities.sort_by_name.find { |ne| ne.name == e.name }
      if found
        ret[:existing].push([ e, found ])
      else
        ret[:added].push(e)
      end
    end

    @previous_version.entities.each do |e|
      found = @version.entities.find { |ne| ne.name == e.name }
      unless found
        ret[:removed].push(e)
      end
    end

    ret
  end
end
