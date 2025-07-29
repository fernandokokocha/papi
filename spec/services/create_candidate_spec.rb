require "rails_helper"

describe Candidate::Create do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  let(:valid_params) {
    {
      candidate: {
        project_id: project.id,
        name: 'rc1'
      },
      version: {
        name: "v1",
        order: 1,
        endpoints_attributes: [
          { url: "/",
            http_verb: "verb_get",
            original_output_string: "",
            original_input_string: "",
            auth: "bearer"
          }
        ],
        entities_attributes: [
          { name: "User",
            original_root: "{ name: string }"
          }
        ]
      }
    }
  }

  subject { Candidate::Create.new(valid_params) }

  context "candidate" do
    it "is created" do
      expect { subject.call }.to change(Candidate, :count).by(1)
    end

    it "is open" do
      subject.call
      candidate = Candidate.last
      expect(candidate).to be_open
    end

    it "has base version" do
      subject.call
      candidate = Candidate.last
      expect(candidate.base_version).to exists
    end
  end

  context "version" do
    it "is created" do
      expect { subject.call }.to change(Version, :count).by(1)
    end
  end
end
