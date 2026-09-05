FactoryBot.define do
  factory :candidate do
    name { "MyString" }
    order { 1 }
    aasm_state { "open" }
    association :project
    # Candidate::Merge and the rejection both stamp the decision, so a decided
    # candidate without a time cannot exist outside a factory.
    decided_at { Time.current unless aasm_state == "open" }
  end
end
