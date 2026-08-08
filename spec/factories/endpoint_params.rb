FactoryBot.define do
  factory :endpoint_param do
    name { "id" }
    kind { "string" }
    location { "path" }
    required { true }
    association :endpoint

    trait :query do
      location { "query" }
      required { false }
    end
  end
end
