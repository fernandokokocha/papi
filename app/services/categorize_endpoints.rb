class CategorizeEndpoints
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

    endpoints = @version.endpoints.sort_by_name

    unless @previous_version
      return {
        existing: [],
        added: endpoints,
        removed: []
      }
    end

    ret = {
      existing: [],
      added: [],
      removed: []
    }

    endpoints.each do |e|
      found = @previous_version.endpoints.find { |ne| ne.name == e.name }
      if found
        ret[:existing].push([ e, found ])
      else
        ret[:added].push(e)
      end
    end

    @previous_version.endpoints.sort_by_name.each do |e|
      found = endpoints.find { |ne| ne.name == e.name }
      unless found
        ret[:removed].push(e)
      end
    end

    ret
  end
end
