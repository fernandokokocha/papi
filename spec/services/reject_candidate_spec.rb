require "rails_helper"

def valid_params(project, candidate_name = "rc1", version_name = "rc1")
  {
    candidate: {
      project_id: project.id,
      name: candidate_name
    },
    version: {
      name: version_name,
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
end

describe Candidate::Reject do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  before do
    create_service = Candidate::Create.new(valid_params(project))
    create_service.call
    @candidate = create_service.candidate
    @version = @candidate.latest_version
  end

  subject { Candidate::Reject.new(@candidate) }

  it "does not create new version for the project" do
    expect(project.versions.count).to eq(0)
    subject.call
    expect(project.versions.count).to eq(0)
  end

  it "does not rename the version" do
    expect(@version.name).to eq("rc1")
    subject.call
    expect(@version.reload.name).to eq("rc1")
  end

  it "changes candidate state to merged" do
    expect(@candidate).to be_open
    subject.call
    expect(@candidate).to be_rejected
  end
end
