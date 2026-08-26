require "rails_helper"

describe "Design preview requests", type: :request do
  describe "#show" do
    it "renders without touching the database" do
      get design_preview_path

      expect(response).to have_http_status(:ok)
    end

    it "shows every card state" do
      get design_preview_path

      %w[Endpoint Entity].each do |kind|
        %w[unchanged changed added removed].each do |state|
          expect(response.body).to include("#{kind} · #{state}")
        end
      end
    end

    it "shows the tints the schema helper hands out" do
      get design_preview_path

      SchemaHelper::CHANGE_TINTS.each_value { |tint| expect(response.body).to include(tint) }
      SchemaHelper::TYPE_TINTS.each_value { |tint| expect(response.body).to include(tint) }
    end
  end
end
