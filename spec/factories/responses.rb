FactoryBot.define do
  factory :response do
    code { "MyString" }
    note { "MyString" }
    association :endpoint
  end
end
