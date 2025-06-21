FactoryBot.define do
  factory :entity do
    name { "TestEntity" }
    association :version
    association :root, factory: :object_node
  end
end
