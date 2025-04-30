FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    url { "http://example.com/resource" }
    original_endpoint_root { "{}" }
    association :version
    association :endpoint_root, factory: :object_node
  end
end
