class Version::CategorizeByName
  def initialize(previous_collection, collection)
    @previous_collection = previous_collection.sort_by_name
    @collection = collection.sort_by_name
  end

  def call
    unless @collection
      return {
        existing: [],
        added: [],
        removed: []
      }
    end

    unless @previous_collection
      return {
        existing: [],
        added: @collection,
        removed: []
      }
    end

    ret = {
      existing: [],
      added: [],
      removed: []
    }

    @collection.each do |e|
      found = @previous_collection.find { |ne| ne.name == e.name }
      if found
        ret[:existing].push([ e, found ])
      else
        ret[:added].push(e)
      end
    end

    @previous_collection.each do |e|
      found = @collection.find { |ne| ne.name == e.name }
      unless found
        ret[:removed].push(e)
      end
    end

    ret
  end
end
