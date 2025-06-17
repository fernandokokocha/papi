FactoryBot.define do
  factory :user do
    email_address { "user@example.com" }
    password { "password" }
    group
  end
end
