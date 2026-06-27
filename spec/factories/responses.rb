FactoryBot.define do
  factory :response do
    code { "200" }
    note { "MyString" }
    output { "" }
    association :endpoint
  end
end
