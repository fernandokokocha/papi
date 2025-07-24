FactoryBot.define do
  factory :project do
    name { "Project Alpha" }
    association :group
  end
end
