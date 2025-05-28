FactoryBot.define do
  factory :object_node do
  end

  factory :primitive_node do
    kind { "string" }
  end

  factory :object_attribute do
    sequence(:name) { |n| "attr-#{n}" }
    sequence(:order) { |n| n }
    association :value, factory: :primitive_node
    association :parent, factory: :object_node
  end

  factory :array_node do
    association :value, factory: :primitive_node
  end
end
