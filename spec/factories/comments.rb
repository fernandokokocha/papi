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

    trait :reply do
      parent { association(:comment, candidate: candidate) }
    end
  end
end
