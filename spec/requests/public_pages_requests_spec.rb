require "rails_helper"

describe "Public pages requests", type: :request do
  it "serves the landing page, Demo access and the blog to a signed-out visitor" do
    get root_path
    expect(response.status).to eq(200)

    get demo_access_path
    expect(response.status).to eq(200)

    get posts_path
    expect(response.status).to eq(200)
    expect(response.body).to include(post_path(Blog::Post.all.first.slug))
  end

  it "shows the signed-in visitor their account rather than a log in link" do
    group = FactoryBot.create(:group, name: "Test group")
    user = FactoryBot.create(:user, email_address: "test@example.com", password: "password", group: group)
    sign_in(user)

    get root_path

    expect(response.body).to include(user.email_address)
    expect(response.body).to include("Log out")
  end

  it "gives every public page a description a link preview can read" do
      get root_path
      expect(response.body).to include(%(<meta name="description" content="Papi describes an HTTP API))
      expect(response.body).to include(%(<meta property="og:url" content="#{root_url}">))

      post = Blog::Post.all.first
      get post_path(post.slug)
      expect(response.body).to include(%(<meta name="description" content="#{post.summary}">))
    end

  it "renders a post and 404s an unknown slug" do
    post = Blog::Post.all.first

    get post_path(post.slug)
    expect(response.status).to eq(200)
    expect(response.body).to include(post.title)

    get post_path("no-such-post")
    expect(response.status).to eq(404)
  end
end
