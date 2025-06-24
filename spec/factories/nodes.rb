FactoryBot.define do
  factory :object_node, class: Node::Object do
  end

  factory :primitive_node, class: Node::Primitive do
    kind { "string" }
  end

  factory :object_attribute, class: Node::ObjectAttribute do
    sequence(:name) { |n| "attr-#{n}" }
    sequence(:order) { |n| n }
    association :value, factory: :primitive_node
    association :parent, factory: :object_node
  end

  factory :array_node, class: Node::Array do
    association :value, factory: :primitive_node
  end

  factory :nothing_node, class: Node::Nothing do
  end

  factory :entity_node, class: Node::Entity do
    association :entity
  end
end
