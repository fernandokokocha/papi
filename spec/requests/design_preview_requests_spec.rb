require "rails_helper"

describe "Design preview requests", type: :request do
  describe "#show" do
    it "renders every endpoint and entity state through the real partials" do
      get design_preview_path

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("/users")
      expect(response.body).to include("per_page")
      expect(response.body).to include("PaginationMeta")
    end

    it "previews a param thread against an endpoint that actually has that param" do
      get design_preview_path

      expect(response.body).to include("DELETE /users/:userId → :userId")
    end
  end
end
