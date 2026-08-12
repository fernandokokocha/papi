FactoryBot.define do
  factory :auth_method do
    name { "UserToken" }
    kind { "bearer" }
    association :version
  end
end
