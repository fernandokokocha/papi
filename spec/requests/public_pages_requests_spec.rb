require "rails_helper"

describe "Public pages requests", type: :request do
  it "serves the landing page, About and the blog to a signed-out visitor" do
    get root_path
    expect(response.status).to eq(200)

    get about_path
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

  it "renders a post and 404s an unknown slug" do
    post = Blog::Post.all.first

    get post_path(post.slug)
    expect(response.status).to eq(200)
    expect(response.body).to include(post.title)

    get post_path("no-such-post")
    expect(response.status).to eq(404)
  end
end
