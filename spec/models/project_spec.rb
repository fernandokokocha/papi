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
end
