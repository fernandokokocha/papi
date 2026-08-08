require "rails_helper"

describe "OpenAPI import requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "Shop", group: group }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "outsider@example.com", password: "password", group: another_group }

  let(:document) do
    {
      "openapi" => "3.1.0",
      "info" => { "title" => "Shop", "version" => "1" },
      "paths" => { "/users" => { "get" => { "responses" => { "200" => { "description" => "The users" } } } } }
    }.to_json
  end

  def upload(content, filename: "shop.json")
    file = Tempfile.new(filename)
    file.write(content)
    file.rewind

    post project_openapi_import_path(project_name: project.name),
      params: { document: Rack::Test::UploadedFile.new(file.path, "application/json", original_filename: filename) }
  end

  it "shows the upload form" do
    sign_in(user)
    get new_project_openapi_import_path(project_name: project.name)

    expect(response.status).to eq(200)
    expect(response.body).to include("Import OpenAPI")
  end

  it "opens a candidate from the uploaded document and goes to it" do
    sign_in(user)
    upload(document)

    candidate = project.candidates.sole
    expect(response).to redirect_to(project_candidate_path(project_name: "Shop", name: candidate.name))
    expect(candidate.latest_version.endpoints.map(&:name)).to eq([ "GET /users" ])
    expect(candidate.author).to eq(user)
  end

  it "sends an unreadable document back to the form with the reason" do
    sign_in(user)
    upload("openapi: [")

    expect(response).to redirect_to(new_project_openapi_import_path(project_name: "Shop"))
    expect(flash[:alert]).to match(/neither JSON nor YAML/)
    expect(project.candidates).to be_empty
  end

  it "refuses to import while a candidate is open" do
    FactoryBot.create(:candidate, project: project, name: "rc1", order: 1)
    sign_in(user)
    upload(document)

    expect(response).to redirect_to(new_project_openapi_import_path(project_name: "Shop"))
    expect(flash[:alert]).to match(/already has an open candidate/)
  end

  it "does not accept users from another group" do
    sign_in(another_user)
    upload(document)

    expect(response.status).to eq(302)
    expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    expect(project.candidates).to be_empty
  end

  it "does not accept a signed out visitor" do
    upload(document)

    expect(response).to redirect_to(new_session_path)
    expect(project.candidates).to be_empty
  end
end
