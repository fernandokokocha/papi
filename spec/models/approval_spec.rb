require "rails_helper"

describe Approval do
  let(:group) { FactoryBot.create :group }
  let(:author) { FactoryBot.create :user, group: group }
  let(:reviewer) { FactoryBot.create :user, group: group }
  let(:project) { FactoryBot.create :project, group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, author: author }

  it "lets a reviewer approve once" do
    expect(FactoryBot.build(:approval, candidate: candidate, user: reviewer)).to be_valid

    FactoryBot.create :approval, candidate: candidate, user: reviewer

    expect(FactoryBot.build(:approval, candidate: candidate, user: reviewer)).not_to be_valid
  end

  it "refuses the candidate author" do
    approval = FactoryBot.build :approval, candidate: candidate, user: author

    expect(approval).not_to be_valid
    expect(approval.errors[:user]).to include("cannot approve their own candidate")
  end

  it "counts approvers on the candidate" do
    FactoryBot.create :approval, candidate: candidate, user: reviewer

    expect(candidate.approvers).to eq([ reviewer ])
    expect(candidate.approved_by?(reviewer)).to be true
    expect(candidate.approved_by?(author)).to be false
  end
end
