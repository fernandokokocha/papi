require "rails_helper"

describe Project, type: :model do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  context "given no versions" do
    it "#next_version_order is 1" do
      expect(project.next_version_order).to eq(1)
    end

    it "#next_version_name is v1" do
      expect(project.next_version_name).to eq("v1")
    end
  end

  context "given a version" do
    let!(:version) { FactoryBot.create :version, project: project, order: 1 }

    it "#next_version_order is 2" do
      expect(project.next_version_order).to eq(2)
    end

    it "#next_version_name is v2" do
      expect(project.next_version_name).to eq("v2")
    end
  end

  context "given two versions" do
    let!(:version1) { FactoryBot.create :version, project: project, name: "v1", order: 1 }
    let!(:version2) { FactoryBot.create :version, project: project, name: "v2", order: 2 }

    it "#next_version_order is 3" do
      expect(project.next_version_order).to eq(3)
    end

    it "#next_version_name is v3" do
      expect(project.next_version_name).to eq("v3")
    end
  end

  describe "#history" do
    it "returns candidates newest-first" do
      first = FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)
      second = FactoryBot.create(:candidate, project: project, name: "rc2", order: 2)

      expect(project.history.to_a).to eq([ second, first ])
    end
  end

  describe "#events" do
    let(:author) { FactoryBot.create(:user, email_address: "author@example.com", group: group) }
    let(:decider) { FactoryBot.create(:user, email_address: "decider@example.com", group: group) }

    it "emits a created event per candidate and a decision event when decided, newest-first" do
      FactoryBot.create(:candidate, project: project, name: "rc1", order: 1, author: author,
                        aasm_state: "merged", decided_by: decider, decided_at: 1.hour.ago, created_at: 3.hours.ago)
      FactoryBot.create(:candidate, project: project, name: "rc2", order: 2, author: author, created_at: 30.minutes.ago)

      verbs = project.events.map(&:verb)

      expect(verbs).to eq([ :created, :merged, :created ])
      expect(project.events.map { |e| e.at }).to eq(project.events.map(&:at).sort.reverse)
    end

    it "attaches the promoted version to a merge event" do
      candidate = FactoryBot.create(:candidate, project: project, name: "rc1", order: 1, aasm_state: "merged", decided_at: 1.hour.ago)
      version = FactoryBot.create(:version, project: project, candidate: candidate, name: "v1", order: 1)

      merge_event = project.events.find { |e| e.verb == :merged }

      expect(merge_event.version).to eq(version)
    end
  end
end
