require "rails_helper"

# The test environment's cache is a null store, whose increment answers nil and
# so never trips a limit. That is what keeps the rest of the suite from sharing
# one 60-request bucket, so the counting store is lent to these examples alone.
describe "Rate limits", type: :request do
  let(:group) { FactoryBot.create :group, name: "Test group" }
  let(:user) { FactoryBot.create :user, email_address: "test@example.com", password: "password", group: group }
  let(:counter) { ActiveSupport::Cache::MemoryStore.new }

  before do
    allow(ActionController::Base.cache_store).to receive(:increment) do |key, amount, **options|
      counter.increment(key, amount, **options)
    end
  end

  it "refuses the 61st request in a minute" do
    sign_in(user)

    60.times { get projects_path }
    expect(response.status).to eq(200)

    get projects_path
    expect(response.status).to eq(429)
  end

  it "counts one bucket across controllers, not one per controller" do
    project = FactoryBot.create(:project, name: "proj", group: group)
    sign_in(user)

    30.times { get projects_path }
    30.times { get project_timeline_path(project.name) }

    get projects_path
    expect(response.status).to eq(429)
  end

  it "keys authenticated traffic by user, so a colleague on the same address is unaffected" do
    colleague = FactoryBot.create :user, email_address: "colleague@example.com", password: "password", group: group
    sign_in(user)
    61.times { get projects_path }
    expect(response.status).to eq(429)

    sign_in(colleague)
    get projects_path
    expect(response.status).to eq(200)
  end

  it "holds password resets to five in a quarter of an hour" do
    5.times { post passwords_path, params: { email_address: user.email_address } }
    expect(response).to redirect_to(new_session_path)

    post passwords_path, params: { email_address: user.email_address }

    expect(response).to redirect_to(new_password_url)
    expect(flash[:alert]).to eq("Try again later.")
  end
end
