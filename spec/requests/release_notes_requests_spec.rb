require "rails_helper"

describe "Release notes requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:admin) { FactoryBot.create :user, email_address: "admin@example.com", password: "password", group: group, role: 1 }
  let(:project) { FactoryBot.create :project, name: "project", group: group }

  let(:valid_params) {
    {
      candidate: { project_id: project.id, name: "rc1", order: 1 },
      version: {
        name: "v1",
        order: 1,
        release_notes: "Adds the search endpoint.\n\nAsked for by the mobile team.",
        endpoints_attributes: [
          { path: "/", http_verb: "verb_get", input: "",
            responses: { "200" => { note: "ok", output: "string" } } }
        ]
      }
    }
  }

  def create_candidate
    post project_candidates_path(project.name), params: valid_params
    Candidate.last
  end

  it "persists the notes the author typed into the version" do
    sign_in(admin)
    create_candidate

    expect(Version.last.release_notes).to eq("Adds the search endpoint.\n\nAsked for by the mobile team.")
  end

  it "rewrites the notes when the candidate is updated" do
    sign_in(admin)
    candidate = create_candidate

    patch project_candidate_path(project_name: project.name, name: candidate.name),
          params: valid_params.deep_merge(version: { release_notes: "Reworded." })

    expect(candidate.latest_version.reload.release_notes).to eq("Reworded.")
  end

  it "prefills the editor with what is already on the candidate's version" do
    sign_in(admin)
    candidate = create_candidate

    get edit_project_candidate_path(project_name: project.name, name: candidate.name)

    expect(response.body).to include("Adds the search endpoint.")
  end

  it "renders the notes on the candidate page, paragraph by paragraph" do
    sign_in(admin)
    candidate = create_candidate

    get project_candidate_path(project.name, candidate.name)

    expect(response.body).to include("Release Notes")
    expect(response.body).to include("<p class=\"text-sm text-gray-700\">Adds the search endpoint.</p>")
    expect(response.body).to include("<p class=\"text-sm text-gray-700\">Asked for by the mobile team.</p>")
  end

  it "renders the notes on the published version page" do
    sign_in(admin)
    candidate = create_candidate
    post project_candidate_merge_path(project.name, candidate.name)

    get project_version_path(project.name, candidate.reload.promoted_version.name)

    expect(response.body).to include("Adds the search endpoint.")
  end

  it "shows markup as the text it was typed as, so no tag is lost and none runs" do
    sign_in(admin)
    post project_candidates_path(project.name),
         params: valid_params.deep_merge(version: { release_notes: "<b>never</b> return a list of < 100" })
    candidate = Candidate.last

    get project_candidate_path(project.name, candidate.name)

    expect(response.body).to include("&lt;b&gt;never&lt;/b&gt; return a list of &lt; 100")
  end

  describe "comments" do
    def comment_on_release_notes(candidate, body)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: body, scope: "release_notes", part: "whole" } }
    end

    it "anchors a thread to the notes and shows it under the card" do
      sign_in(admin)
      candidate = create_candidate

      comment_on_release_notes(candidate, "Mention the deprecation here too")
      get project_candidate_path(project.name, candidate.name)

      expect(Comment.last.anchor_key).to eq(CommentAnchor.for_release_notes.key)
      expect(response.body).to include("Mention the deprecation here too")
      expect(response.body).to include("Release notes")
    end

    it "offers the region on a candidate whose author wrote nothing, so the gap can be raised" do
      sign_in(admin)
      post project_candidates_path(project.name), params: valid_params.deep_merge(version: { release_notes: "" })

      get project_candidate_path(project.name, Candidate.last.name)

      expect(response.body).to include("No release notes")
      expect(response.body).to include(CommentAnchor.for_release_notes.dom_id)
    end

    it "leaves the region off a published version with no notes, where nobody can comment anyway" do
      sign_in(admin)
      post project_candidates_path(project.name), params: valid_params.deep_merge(version: { release_notes: "" })
      candidate = Candidate.last
      post project_candidate_merge_path(project.name, candidate.name)

      get project_version_path(project.name, candidate.reload.promoted_version.name)

      expect(response.body).not_to include("No release notes")
      expect(response.body).not_to include("Release notes")
    end

    it "counts the threads in the sidebar" do
      sign_in(admin)
      candidate = create_candidate
      comment_on_release_notes(candidate, "One")
      comment_on_release_notes(candidate, "Two")

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("sidebar_count_#{CommentAnchor.for_release_notes.dom_id}")
      expect(CandidateComments.for(candidate).sidebar_count(CommentAnchor.for_release_notes)).to eq(2)
    end

    it "shows the feedback read-only beside the textarea while the author edits" do
      sign_in(admin)
      candidate = create_candidate
      comment_on_release_notes(candidate, "Too terse")

      get edit_project_candidate_path(project_name: project.name, name: candidate.name)

      expect(response.body).to include("Too terse")
      expect(response.body).not_to include("Resolve thread")
    end

    it "survives the merge, staying on the candidate that raised it" do
      sign_in(admin)
      candidate = create_candidate
      comment_on_release_notes(candidate, "Good enough")
      post project_candidate_merge_path(project.name, candidate.name)

      get project_candidate_path(project.name, candidate.name)

      expect(response.body).to include("Good enough")
    end
  end

  it "starts a new candidate with an empty notes field, not the previous version's" do
    sign_in(admin)
    candidate = create_candidate
    post project_candidate_merge_path(project.name, candidate.name)

    get new_project_candidate_path(project_name: project.name)

    expect(response.body).to include("Release Notes")
    expect(response.body).not_to include("Adds the search endpoint.")
  end
end
