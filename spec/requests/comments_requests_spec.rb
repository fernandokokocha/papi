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

    it "answers a turbo stream that appends a reply into its thread" do
      root = FactoryBot.create :comment, candidate: candidate
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Agreed.", parent_id: root.id } },
           headers: { "Accept" => "text/vnd.turbo-stream.html" }

      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(turbo_actions).to include(
        [ "append", "replies_comment_#{root.id}" ],
        [ "update", "reply_form_comment_#{root.id}" ]
      )
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

    it "renders a Turbo Stream targeting the anchor container when the request is turbo_stream" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Anchored", scope: "entity", part: "whole", entity_name: "User" } },
           as: :turbo_stream

      dom_id = Comment.last.anchor.dom_id
      expect(response.media_type).to eq("text/vnd.turbo-stream.html")
      expect(turbo_actions).to include(
        [ "append", dom_id ],
        [ "replace", "#{dom_id}_form" ]
      )
    end

    it "live-updates the endpoint sidebar count when an anchored root is posted" do
      sign_in(user)
      post project_candidate_comments_path(project.name, candidate.name),
           params: { comment: { body: "Anchored", scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: "0" } },
           as: :turbo_stream

      sidebar_id = "sidebar_count_#{CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users", endpoint_http_verb: 0).dom_id}"
      expect(turbo_actions).to include([ "update", sidebar_id ])
      expect(response.body).to include(%(title="1 comment"))
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

      it "streams the thread into the param's inline container" do
        sign_in(user)
        post_param_comment

        expect(turbo_actions).to include(
          [ "append", anchor.dom_id ],
          [ "replace", "#{anchor.dom_id}_form" ]
        )
      end

      it "counts a param thread into the endpoint's sidebar badge" do
        sign_in(user)
        post_param_comment

        sidebar_id = "sidebar_count_#{CommentAnchor.new(scope: "endpoint", part: "whole", endpoint_path: "/users/:id", endpoint_http_verb: 0).dom_id}"
        expect(turbo_actions).to include([ "update", sidebar_id ])
        expect(response.body).to include(%(title="1 comment"))
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

      it "makes each param row its own comment region" do
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        expect(response.body).to include(%(data-comment-region="#{anchor.dom_id}"))
      end

      it "renders a param thread inline under its row" do
        FactoryBot.create :comment, :param_scope, candidate: candidate, author: user, body: "Should this be a slug?"
        sign_in(user)
        get project_candidate_path(project.name, candidate.name)

        expect(response.body).to include(%(id="#{anchor.dom_id}"))
        expect(response.body).to include("Should this be a slug?")
        expect(response.body).to include("GET /users/:id → :id")
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

      it "streams the thread inline after its row when the block was expanded" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: line_params.merge(expanded: "true"), as: :turbo_stream

        region = CommentAnchor.new(scope: "response", part: "output",
                                   endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
        expect(response.media_type).to eq("text/vnd.turbo-stream.html")
        expect(turbo_actions).to include(
          [ "after", %([data-line-pick="#{region.dom_id}"] [data-line-index="4"]) ],
          [ "remove", "#{region.dom_id}_form" ],
          [ "update", "#{region.dom_id}_form_home" ]
        )
        expect(response.body).to include(">Inlined<")
      end

      it "streams the thread into the below-block container when the block was collapsed" do
        sign_in(user)
        post project_candidate_comments_path(project.name, candidate.name),
             params: line_params.merge(expanded: "false"), as: :turbo_stream

        region = CommentAnchor.new(scope: "response", part: "output",
                                   endpoint_path: "/users", endpoint_http_verb: 0, response_code: "200")
        expect(turbo_actions).to include(
          [ "append", "#{region.dom_id}_line_threads" ],
          [ "remove", "#{region.dom_id}_form" ],
          [ "update", "#{region.dom_id}_form_home" ]
        )
        expect(response.body).to include(">Collapsed<")
        expect(turbo_actions.map(&:first)).not_to include("after")
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

        it "streams the thread inline after its row when the block was expanded" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: input_params.merge(expanded: "true"), as: :turbo_stream

          expect(turbo_actions).to include(
            [ "after", %([data-line-pick="#{region.dom_id}"] [data-line-index="1"]) ],
            [ "remove", "#{region.dom_id}_form" ],
            [ "update", "#{region.dom_id}_form_home" ]
          )
          expect(response.body).to include(">Inlined<")
        end

        it "streams the thread into the below-block container when the block was collapsed" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: input_params.merge(expanded: "false"), as: :turbo_stream

          expect(turbo_actions).to include(
            [ "append", "#{region.dom_id}_line_threads" ],
            [ "remove", "#{region.dom_id}_form" ],
            [ "update", "#{region.dom_id}_form_home" ]
          )
          expect(response.body).to include(">Collapsed<")
        end

        it "counts an input thread into the endpoint's sidebar badge" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: input_params, as: :turbo_stream

          sidebar_id = "sidebar_count_#{CommentAnchor.for_endpoint(endpoint).dom_id}"
          expect(turbo_actions).to include([ "update", sidebar_id ])
          expect(response.body).to include(%(title="1 comment"))
        end

        it "appends a region thread to the input anchor when no line is picked" do
          sign_in(user)
          post project_candidate_comments_path(project.name, candidate.name),
               params: { comment: { body: "The whole body needs work", scope: "endpoint", part: "input",
                                    endpoint_path: "/users", endpoint_http_verb: "0" } },
               as: :turbo_stream

          expect(turbo_actions).to include(
            [ "append", region.dom_id ],
            [ "replace", "#{region.dom_id}_form" ]
          )
          expect(Comment.last.anchor_snapshot).to be_nil
        end
      end
    end
  end
end
