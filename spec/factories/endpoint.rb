FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    url { "http://example.com/resource" }
    original_input_string { "{}" }
    original_output_string { "{}" }
    association :version
    association :input, factory: :object_node
    association :output, factory: :object_node
  end
end
