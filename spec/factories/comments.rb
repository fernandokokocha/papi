FactoryBot.define do
  factory :comment do
    association :candidate
    association :author, factory: :user
    body { "Looks good to me." }
    add_attribute(:scope) { "candidate" }
    part { "whole" }

    trait :endpoint_scope do
      add_attribute(:scope) { "endpoint" }
      endpoint_path { "/users" }
      endpoint_http_verb { 0 }
    end

    trait :endpoint_input do
      add_attribute(:scope) { "endpoint" }
      part { "input" }
      endpoint_path { "/users" }
      endpoint_http_verb { 0 }
    end

    trait :entity_scope do
      add_attribute(:scope) { "entity" }
      entity_name { "User" }
    end

    trait :response_scope do
      add_attribute(:scope) { "response" }
      endpoint_path { "/users" }
      endpoint_http_verb { 0 }
      response_code { "200" }
    end

    trait :param_scope do
      add_attribute(:scope) { "param" }
      endpoint_path { "/users/:id" }
      endpoint_http_verb { 0 }
      param_name { "id" }
      param_location { "path" }
    end

    trait :reply do
      parent { association(:comment, candidate: candidate) }
    end

    trait :resolved do
      resolved_at { Time.current }
      association :resolved_by, factory: :user
    end
  end
end
