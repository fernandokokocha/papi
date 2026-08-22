require "rails_helper"

describe "Comments requests", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:project) { FactoryBot.create :project, name: "project", group: group }
  let(:candidate) { FactoryBot.create :candidate, project: project, name: "rc1" }

  let(:another_group) { FactoryBot.create :group, name: "Test group 2" }
  let(:another_user) { FactoryBot.create :user, email_address: "test2@example.com", password: "password", group: another_group }

  describe "#create" do
    it "does not create a comment for a user outside the group" do
      sign_in(another_user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Sneaky" } }
      }.not_to change(Comment, :count)
      expect(response).to redirect_to("/")
      expect(flash[:alert]).to eq("You are not authorized to perform this action.")
    end

    it "redirects with an alert when the comment is invalid" do
      sign_in(user)
      expect {
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "" } }
      }.not_to change(Comment, :count)
      expect(response).to redirect_to(project_candidate_path(project.name, candidate.name))
      expect(flash[:alert]).to eq("Comment could not be posted.")
    end

    it "ignores a client-supplied author_id" do
      forged = FactoryBot.create :user, email_address: "forged@example.com", group: group
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Hi", author_id: forged.id } }
      expect(Comment.last.author).to eq(user)
    end

    it "answers a turbo stream that appends the new thread and resets the form" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "First!" } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(turbo_actions).to include(
        [ "append", "candidate_comment_threads" ],
        [ "remove", "no_comments_message" ],
        [ "update", "new_comment_form" ]
      )
      expect(response.body).to include("First!")

      textarea_contents = response.body.scan(%r{<textarea[^>]*>([\s\S]*?)</textarea>}).flatten
      expect(textarea_contents).not_to be_empty
      expect(textarea_contents).to all(be_blank)
    end

    it "answers a turbo stream that replaces the thread with the reply in it" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(turbo_actions).to include([ "replace", "comment_#{root.id}" ])
      expect(response.body).to include("Agreed.")
    end

    it "replaces the whole thread when a reply reopens a resolved parent" do
      root = FactoryBot.create :comment, :resolved, candidate: candidate, author: user
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "One more thing", parent_id: root.id } }, as: :turbo_stream

      expect(turbo_actions).to include([ "replace", ActionView::RecordIdentifier.dom_id(root) ])
      expect(response.body).to include("One more thing")
      expect(response.body).not_to include("Resolved by")
    end

    it "renders a Turbo Stream replacing the anchor's pin when the request is turbo_stream" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Anchored", scope: "entity", part: "whole", entity_name: "User" } },
           as: :turbo_stream

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(turbo_actions).to include([ "replace", Comment.last.anchor.dom_id ])
      expect(response.body).to include("Anchored")
    end

    it "live-updates the endpoint sidebar count when an anchored root is posted" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Anchored", scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: "0" } },
           as: :turbo_stream

      sidebar_id = "sidebar_count_#{CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0).dom_id}"
      expect(turbo_actions).to include([ "update", sidebar_id ])
      expect(response.body).to include(%(title="1 thread"))
    end

    describe "param-anchored roots" do
      let(:anchor) do
        CommentAnchor.new(scope: "param", part: "whole",
                          endpoint_path: "/users/:id", endpoint_http_verb: 0, param_name: "id", param_location: "path")
      end

      def post_param_comment
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Should this be a slug?", scope: "param", part: "whole",
                                  endpoint_path: "/users/:id", endpoint_http_verb: "0",
                                  param_name: "id", param_location: "path" } },
             as: :turbo_stream
      end

      it "stores the param name and takes no snapshot" do
        sign_in(user)
        post_param_comment

        expect(Comment.last.param_name).to eq("id")
        expect(Comment.last.anchor.label).to eq("GET /users/:id → :id")
        expect(Comment.last.anchor_snapshot).to be_nil
      end

      it "streams the thread into the param's pin" do
        sign_in(user)
        post_param_comment

        expect(turbo_actions).to include([ "replace", anchor.dom_id ])
        expect(response.body).to include("Should this be a slug?")
      end

      it "counts a param thread into the endpoint's sidebar badge" do
        sign_in(user)
        post_param_comment

        sidebar_id = "sidebar_count_#{CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users/:id", endpoint_http_verb: 0).dom_id}"
        expect(turbo_actions).to include([ "update", sidebar_id ])
        expect(response.body).to include(%(title="1 thread"))
      end

      it "rejects a param anchor with no param name" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: { comment: { body: "Nameless", scope: "param", part: "whole",
                                  endpoint_path: "/users/:id", endpoint_http_verb: "0" } }

        expect(Comment.count).to eq(0)
        expect(flash[:alert]).to eq("Comment could not be posted.")
      end
    end

    describe "param regions on the candidate page" do
      let!(:version) { FactoryBot.create :version, candidate: candidate, project: project, order: 1 }
      let!(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users/:id", http_verb: "verb_get" }
      let(:anchor) { CommentAnchor.for_endpoint_param(endpoint, "id", "path") }

      it "gives each param row its own rail, ready to comment on" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        expect(response.body).to include(%(id="#{anchor.dom_id}"))
        expect(response.body).to include(%(title="Comment here"))
      end

      it "renders a param thread in the row's pin" do
        FactoryBot.create :comment, :param_scope, candidate: candidate, author: user, body: "Should this be a slug?"
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        expect(response.body).to include(%(id="#{anchor.dom_id}"))
        expect(response.body).to include("Should this be a slug?")
        expect(response.body).to include(%(title="1 thread"))
      end
    end

    describe "every place a comment can be anchored" do
      let!(:version) do
        FactoryBot.create :version, candidate: candidate, project: project, order: 1,
                          release_notes: "Adds pagination."
      end
      let!(:auth_method) { FactoryBot.create :auth_method, version: version, name: "UserToken" }
      let!(:entity) { FactoryBot.create :entity, version: version, name: "User", root: "{id:number}" }
      let!(:endpoint) do
        FactoryBot.create :endpoint, version: version, path: "/users/:id", http_verb: "verb_get",
                          note: "Fetches one user.", input: "{page:number}", auth: "UserToken"
      end
      let!(:path_param) { FactoryBot.create :endpoint_param, endpoint: endpoint, name: "id" }
      let!(:query_param) { FactoryBot.create :endpoint_param, :query, endpoint: endpoint, name: "page" }
      let!(:response_200) { FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{name:string}" }

      # Every scope and part CommentTarget accepts, minus the ones the page has
      # no room for: the candidate's own thread lives in the conversation, and a
      # response note shares its response's pin.
      def every_anchor
        {
          "release notes" => CommentAnchor.for_release_notes,
          "endpoint" => CommentAnchor.for_endpoint(endpoint),
          "endpoint note" => CommentAnchor.new(scope: "endpoint", part: "note", endpoint_path: endpoint.path, endpoint_http_verb: 0),
          "endpoint auth" => CommentAnchor.for_endpoint_auth(endpoint),
          "endpoint input" => CommentAnchor.for_endpoint_input(endpoint),
          "input line" => CommentAnchor.for_endpoint_input(endpoint).with_line(1),
          "path param" => CommentAnchor.for_endpoint_param(endpoint, "id", "path"),
          "query param" => CommentAnchor.for_endpoint_param(endpoint, "page", "query"),
          "response" => CommentAnchor.new(scope: "response", part: "whole", endpoint_path: endpoint.path, endpoint_http_verb: 0, response_code: "200"),
          "output line" => CommentAnchor.for_response_output(endpoint, "200").with_line(1),
          "entity" => CommentAnchor.for_entity(entity),
          "entity root line" => CommentAnchor.for_entity_root(entity).with_line(1),
          "auth method" => CommentAnchor.for_auth_method(auth_method),
          "auth method note" => CommentAnchor.new(scope: "auth_method", part: "note", auth_method_name: auth_method.name)
        }
      end

      it "offers a rail on the candidate page" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        missing = every_anchor.reject { |_, anchor| response.body.include?(%(id="#{anchor.dom_id}")) }
        expect(missing.keys).to be_empty
      end

      # A rail outside a comment-host renders, but its + never appears, because
      # only the host's hover reveals it.
      it "puts every rail inside something that reveals it on hover" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        rails = Nokogiri::HTML(response.body).css('[id^="comment_anchor_"]')
        unhosted = rails.reject { |rail| rail.ancestors(".comment-host").any? }

        expect(rails).not_to be_empty
        expect(unhosted.map { |rail| rail["id"] }).to be_empty
      end

      it "accepts a comment posted at each of them" do
        sign_in(user)
        every_anchor.each do |name, anchor|
          expect {
            post project_candidate_comments_path(project.name, candidate.name),
                 params: { comment: { body: "Comment on #{name}" }.merge(anchor.to_columns) }, as: :turbo_stream
          }.to change(Comment, :count).by(1), "posting on #{name} failed: #{flash[:alert]}"
          expect(turbo_actions).to include([ "replace", anchor.dom_id ]), "no pin replaced for #{name}"
        end
      end
    end

    describe "a record the candidate removes" do
      let!(:base_candidate) { FactoryBot.create :candidate, project: project, name: "rc0", aasm_state: "merged" }
      let!(:base_version) { FactoryBot.create :version, project: project, candidate: base_candidate, name: "v1", order: 1 }
      let!(:gone_endpoint) do
        FactoryBot.create :endpoint, version: base_version, path: "/legacy", http_verb: "verb_get",
                          input: "{token:string}"
      end
      let!(:gone_response) { FactoryBot.create :response, endpoint: gone_endpoint, code: "200", output: "{ok:boolean}" }
      let!(:gone_entity) { FactoryBot.create :entity, version: base_version, name: "LegacyToken", root: "{token:string}" }
      let!(:version) { FactoryBot.create :version, project: project, candidate: candidate, name: "v2", order: 2 }

      before { candidate.update!(base_version: base_version) }

      it "still offers its card and region rails" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        expect(response.body).to include(%(id="#{CommentAnchor.for_endpoint(gone_endpoint).dom_id}"))
        expect(response.body).to include(%(id="#{CommentAnchor.for_endpoint_input(gone_endpoint).dom_id}"))
        expect(response.body).to include(%(id="#{CommentAnchor.for_entity(gone_entity).dom_id}"))
      end

      # A line anchor snapshots the record's current text, and there is none.
      it "offers no line rails on its schema" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        line_rails = [
          CommentAnchor.for_endpoint_input(gone_endpoint).with_line(1),
          CommentAnchor.for_response_output(gone_endpoint, "200").with_line(1),
          CommentAnchor.for_entity_root(gone_entity).with_line(1)
        ]
        offered = line_rails.select { |anchor| response.body.include?(%(id="#{anchor.dom_id}")) }
        expect(offered.map(&:label)).to be_empty
      end

      it "keeps a line thread it already carries, with no + beside it" do
        anchor = CommentAnchor.for_entity_root(gone_entity).with_line(0)
        candidate.comments.create!(author: user, body: "Why is this going away?",
                                   **anchor.to_columns, anchor_snapshot: gone_entity.root)
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        pin = Nokogiri::HTML(response.body).at_css(%([id="#{anchor.dom_id}"]))
        expect(pin).to be_present
        expect(pin.text).to include("Why is this going away?")
        expect(pin.css(".pin-icon-plus")).to be_empty
      end
    end

    describe "line-anchored roots" do
      let!(:version) { FactoryBot.create :version, candidate: candidate, project: project, order: 1 }
      let!(:endpoint) { FactoryBot.create :endpoint, version: version, path: "/users", http_verb: "verb_get" }
      let!(:response_200) { FactoryBot.create :response, endpoint: endpoint, code: "200", output: "{total:number,items:[User]}" }
      let!(:entity) { FactoryBot.create :entity, version: version, name: "User", root: "{id:number,email:string}" }
      let(:line_params) do
        { comment: { body: "Pinned to the User row", scope: "response", part: "output",
                     endpoint_path: "/users", endpoint_http_verb: "0", response_code: "200", line: "4" } }
      end

      it "ignores a client-supplied anchor_snapshot" do
        sign_in(user)
        forged = line_params.deep_merge(comment: { anchor_snapshot: "forged" })
        post project_candidate_comments_path(project.name, candidate.name), params: forged

        expect(Comment.last.anchor_snapshot).to eq("{total:number,items:[User]}")
      end

      it "streams the thread into the pin on its own row" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: line_params.merge(sublabel: "line 4"), as: :turbo_stream

        line_anchor = CommentAnchor.new(scope: "response", part: "output", line: 4,
                                        endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(turbo_actions).to include([ "replace", line_anchor.dom_id ])
        expect(response.body).to include("Pinned to the User row")
        expect(response.body).to include("line 4")
      end

      describe "on an endpoint input" do
        let(:input_params) do
          { comment: { body: "Pinned to the name row", scope: "endpoint", part: "input",
                       endpoint_path: "/users", endpoint_http_verb: "0", line: "1" } }
        end
        let(:region) do
          CommentAnchor.new(scope: "endpoint", part: "input", endpoint_path: "/users", endpoint_http_verb: 0)
        end

        before { endpoint.update!(input: "{name:string,email:string}") }

        it "snapshots the endpoint's raw input, ignoring a client-supplied one" do
          sign_in(user)
          forged = input_params.deep_merge(comment: { anchor_snapshot: "forged" })
          post project_candidate_comments_path(project.name, candidate.name), params: forged

          expect(Comment.last.anchor_snapshot).to eq("{name:string,email:string}")
        end

        it "streams the thread into the pin on its own row" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: input_params, as: :turbo_stream

          expect(turbo_actions).to include([ "replace", region.with_line(1).dom_id ])
          expect(response.body).to include("Pinned to the name row")
        end

        it "counts an input thread into the endpoint's sidebar badge" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: input_params, as: :turbo_stream

          sidebar_id = "sidebar_count_#{CommentAnchor.for_endpoint(endpoint).dom_id}"
          expect(turbo_actions).to include([ "update", sidebar_id ])
          expect(response.body).to include(%(title="1 thread"))
        end

        it "appends a region thread to the input anchor when no line is picked" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: { comment: { body: "The whole body needs work", scope: "endpoint", part: "input",
                                    endpoint_path: "/users", endpoint_http_verb: "0" } },
               as: :turbo_stream

          expect(turbo_actions).to include([ "replace", region.dom_id ])
          expect(Comment.last.anchor_snapshot).to be_nil
        end
      end
    end
  end
end
