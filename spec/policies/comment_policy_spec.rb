require "rails_helper"

describe CommentPolicy do
  let(:group) { FactoryBot.create :group }
  let(:author) { FactoryBot.create :user, group: group }
  let(:other) { FactoryBot.create :user, group: group }
  let(:project) { FactoryBot.create :project, group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, author: author }
  let(:comment) { FactoryBot.create :comment, candidate: candidate, author: author }

  describe "#resolve?" do
    it "allows the candidate author" do
      expect(described_class.new(author, comment).resolve?).to be true
    end

    it "denies another group member" do
      expect(described_class.new(other, comment).resolve?).to be false
    end
  end
end
