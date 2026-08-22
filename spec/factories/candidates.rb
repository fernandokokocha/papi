FactoryBot.define do
  factory :candidate do
    name { "MyString" }
    order { 1 }
    association :project
    decided_at { decided_by && Time.current }
  end
end
