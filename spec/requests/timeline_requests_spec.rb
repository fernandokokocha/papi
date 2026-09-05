require "rails_helper"

describe "Timeline requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:author) { FactoryBot.create :user, email_address: "author@example.com", password: "password", group: group, role: 0 }
  let(:reviewer) { FactoryBot.create :user, email_address: "reviewer@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create(:project, name: "proj", group: group) }

def feed
    document = Nokogiri::HTML(response.body)
    document.css("aside").remove
    document.text
  end

  def rail
    Nokogiri::HTML(response.body).css("aside")
  end

  def merged_candidate(name)
    candidate = FactoryBot.create(:candidate, project: project, name: name, aasm_state: "merged",
                                  author: author, decided_by: reviewer, decided_at: Time.current)
    FactoryBot.create(:version, project: project, candidate: candidate, name: "v#{name[-1]}", order: name[-1].to_i)
    candidate
  end

  it "streams every kind of event" do
    candidate = merged_candidate("rc1")
    Approval.create!(candidate: candidate, user: reviewer)
    Comment.create!(candidate: candidate, author: reviewer, body: "one", scope: "candidate", part: "whole")
    Comment.create!(candidate: candidate, author: reviewer, body: "two", scope: "candidate", part: "whole")
    sign_in(author)

    get project_timeline_path(project.name)

    expect(response.body).to include("opened")
    expect(response.body).to include("approved")
    expect(response.body).to include("left 2 comments on")
    expect(response.body).to include("merged")
  end

  it "filters by kind" do
    merged_candidate("rc1")
    sign_in(author)

    get project_timeline_path(project.name, kind: "opened")

    expect(feed).to include("opened")
    expect(feed).not_to include("merged")
  end

  it "filters by candidate" do
    merged_candidate("rc1")
    merged_candidate("rc2")
    sign_in(author)

    get project_timeline_path(project.name, candidate: "rc1")

    expect(feed).to include("rc1")
    expect(feed).not_to include("rc2")
  end

  it "keeps a candidate in the rail when a kind filter empties it" do
    merged_candidate("rc1")
    FactoryBot.create(:candidate, project: project, name: "rc2", author: author)
    sign_in(author)

    get project_timeline_path(project.name, kind: "merged")

    expect(rail.text).to include("rc2")
    expect(rail.css("a").map { |link| link["href"] })
      .not_to include(project_timeline_path(project.name, kind: "merged", candidate: "rc2"))
  end

  it "keeps a kind in the rail when a candidate filter empties it" do
    merged_candidate("rc1")
    FactoryBot.create(:candidate, project: project, name: "rc2", author: author)
    sign_in(author)

    get project_timeline_path(project.name, candidate: "rc2")

    expect(rail.text).to include("Merged")
    expect(rail.css("a").map { |link| link["href"] })
      .not_to include(project_timeline_path(project.name, kind: "merged", candidate: "rc2"))
  end

  it "is reachable from the project page, and leads back to it" do
  sign_in(author)

  get project_path(project.name)
  expect(response.body).to include(project_timeline_path(project.name))

  get project_timeline_path(project.name)
  expect(response.body).to include(project_path(project.name))
end

it "renders an empty stream for a project with no activity" do
    sign_in(author)

    get project_timeline_path(project.name)

    expect(response.status).to eq(200)
    expect(response.body).not_to include("divide-y divide-slate-200")
  end
end
