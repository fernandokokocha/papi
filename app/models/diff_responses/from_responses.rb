class DiffResponses::FromResponses
  attr_accessor :before, :after

  def initialize(responses1, responses2)
    @before = []
    @after = []

    responses2.sort_by(&:code).each do |response|
      matching_responses = responses1.select { |r| r.code === response.code }
      if matching_responses.any?
        matching_response = matching_responses.first
        if matching_response.note === response.note
          @before << DiffResponses::Line.no_change(response.code, response.note)
          @after << DiffResponses::Line.no_change(response.code, response.note)
        else
          @before << DiffResponses::Line.note_changed(response.code, matching_response.note)
          @after << DiffResponses::Line.note_changed(response.code, response.note)
        end
      else
        @before << DiffResponses::Line.blank
        @after << DiffResponses::Line.added(response.code, response.note)
      end
    end

    responses1.sort_by(&:code).each do |response|
      matching_responses = responses2.select { |r| r.code === response.code }
      if matching_responses.empty?
        @before << DiffResponses::Line.removed(response.code, response.note)
        @after << DiffResponses::Line.blank
      end
    end
  end
end
