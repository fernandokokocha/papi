FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    url { "http://example.com/resource" }
    original_input_string { "{}" }
    original_output_string { "{}" }
    association :version
  end
end
