FactoryBot.define do
  factory :version do
    name { "v1" }
    sequence(:order) { |n| n }
    association :project
  end
end
