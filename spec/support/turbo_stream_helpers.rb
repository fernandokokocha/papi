module TurboStreamHelpers
  # [[action, target], ...] for the turbo stream the last request answered.
  def turbo_actions
    Nokogiri::HTML5.fragment(response.body).css("turbo-stream").map do |stream|
      [ stream["action"], stream["target"] || stream["targets"] ]
    end
  end
end

RSpec.configure do |config|
  config.include TurboStreamHelpers, type: :request
end
