require "rails_helper"

describe ApprovalPolicy do
  let(:group) { FactoryBot.create :group }
  let(:author) { FactoryBot.create :user, group: group }
  let(:reviewer) { FactoryBot.create :user, group: group }
  let(:outsider) { FactoryBot.create :user }
  let(:project) { FactoryBot.create :project, group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, author: author }

  def policy_for(user)
    described_class.new(user, Approval.new(candidate: candidate, user: user))
  end

  it "grants approval to any group member who is not the author" do
    expect(policy_for(reviewer).create?).to be true
    expect(policy_for(reviewer).destroy?).to be true
  end

  it "refuses the author" do
    expect(policy_for(author).create?).to be false
  end

  it "refuses someone outside the group" do
    expect(policy_for(outsider).create?).to be false
  end

  it "refuses a candidate that is no longer open" do
    candidate.merge!

    expect(policy_for(reviewer).create?).to be false
  end
end
