FactoryBot.define do
  factory :entity do
    name { "TestEntity" }
    association :version
  end
end
