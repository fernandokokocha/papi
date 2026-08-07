FactoryBot.define do
  factory :endpoint_param do
    name { "id" }
    kind { "string" }
    association :endpoint
  end
end
