class Version::CategorizeByName
  def initialize(previous_collection, collection)
    @previous_collection = previous_collection
    @collection = collection
  end

  def call
    @collection.each do |e|
      found = @previous_collection.find { |ne| ne.name == e.name }
      if found
        e.annotation = "existing"
        e.previous = found
      else
        e.annotation = "added"
        e.previous = nil
      end
    end

    not_present_in_present = @previous_collection.select do |e|
      found = @collection.find { |ne| ne.name == e.name }
      not found
    end

    not_present_in_present.each do |e|
      e.annotation = "removed"
    end

    (@collection + not_present_in_present).sort_by { |e| e.sort_name }
  end
end
