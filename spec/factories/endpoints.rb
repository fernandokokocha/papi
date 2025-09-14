FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    path { "/resource" }
    output { "" }
    output_error { "" }
    association :version
  end
end
