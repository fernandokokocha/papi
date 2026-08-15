FactoryBot.define do
  factory :approval do
    association :candidate
    association :user
  end
end
