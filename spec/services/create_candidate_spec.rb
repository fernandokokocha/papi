require "rails_helper"

describe Candidate::Create do
  let!(:group) { Group.create!(name: "Test group") }
  let!(:user) { User.create!(email_address: "test@example.com", password: "password", group: group) }
  let!(:project) { Project.create!(name: "project", group: group) }

  before { Current.session = Session.new(user: user) }

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
          { path: "/",
            http_verb: "verb_get",
            auth: "bearer",
            input: "{query:string}",
            responses: { "200" => { note: "ok", output: "User" } }
          }
        ],
        entities_attributes: [
          { name: "User",
            root: "{ name: string }"
          }
        ]
      }
    }
  }

  subject { Candidate::Create.new(valid_params) }

  context "with no prior versions" do
    it "creates candidate" do
      expect { subject.call }.to change(Candidate, :count).by(1)
    end

    it "candidate is open" do
      subject.call
      candidate = Candidate.last
      expect(candidate).to be_open
    end

    it "candidate has no base version" do
      subject.call
      candidate = Candidate.last
      expect(candidate.base_version).to be_nil
    end

    it "creates version" do
      expect { subject.call }.to change(Version, :count).by(1)
    end

    it "persists the per-response output schema" do
      subject.call
      response = Endpoint.last.responses.find_by(code: "200")
      expect(response.output).to eq("User")
      expect(response.note).to eq("ok")
    end

    it "persists the endpoint input schema" do
      subject.call
      expect(Endpoint.last.input).to eq("{query:string}")
    end

    it "persists the kind chosen for each path param" do
      params = valid_params.deep_dup
      params[:version][:endpoints_attributes][0][:path] = "/posts/:postId/comments/:commentId"
      params[:version][:endpoints_attributes][0][:params] = {
        "postId" => { kind: "number" }, "commentId" => { kind: "string" }
      }

      Candidate::Create.new(params).call

      expect(Endpoint.last.path_params.map { |p| [ p.name, p.kind ] })
        .to eq([ [ "postId", "number" ], [ "commentId", "string" ] ])
    end

    it "sets the author when one is passed" do
      Candidate::Create.new(valid_params, author: user).call
      expect(Candidate.last.author).to eq(user)
    end
  end

  context "with query params" do
    let(:query_params) {
      valid_params.deep_merge(version: { endpoints_attributes: [ valid_params[:version][:endpoints_attributes].first.merge(
        query_params: { "q" => { kind: "string", required: "true" },
                        "page" => { kind: "number", required: "false" } }
      ) ] })
    }

    it "stores them with their location and requiredness, sorted by name" do
      service = Candidate::Create.new(query_params)
      service.call

      endpoint = service.candidate.latest_version.endpoints.first
      expect(endpoint.query_params.map { |p| [ p.name, p.kind, p.required ] })
        .to eq([ [ "page", "number", false ], [ "q", "string", true ] ])
    end

    it "keeps them out of the path params" do
      service = Candidate::Create.new(query_params)
      service.call

      expect(service.candidate.latest_version.endpoints.first.path_params).to eq([])
    end
  end

  context "with prior versions" do
    let!(:version1) { FactoryBot.create(:version, project: project, name: "v1") }
    let!(:version2) { FactoryBot.create(:version, project: project, name: "v2") }

    it "creates candidate" do
      expect { subject.call }.to change(Candidate, :count).by(1)
    end

    it "candidate is open" do
      subject.call
      candidate = Candidate.last
      expect(candidate).to be_open
    end

    it "candidate has base version as the latest version" do
      subject.call
      candidate = Candidate.last
      expect(candidate.base_version.id).to equal(version2.id)
    end

    it "creates version" do
      expect { subject.call }.to change(Version, :count).by(1)
    end
  end
end
