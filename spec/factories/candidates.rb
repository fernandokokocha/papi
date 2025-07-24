FactoryBot.define do
  factory :candidate do
    name { "MyString" }
    order { 1 }
    association :project
  end
end
