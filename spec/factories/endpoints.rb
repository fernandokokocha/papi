FactoryBot.define do
  factory :endpoint do
    http_verb { "verb_get" }
    path { "/resource" }
    association :version
  end
end
