require "rails_helper"

RSpec.describe "Scripts", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:json) { JSON.parse(response.body) }

  let(:script_params) do
    {
      title: "新劇本",
      description: "簡介",
      difficulty: 0,
      male_slots: 2,
      female_slots: 2,
      any_slots: 0,
      genres: [ 0 ]
    }
  end

  describe "GET /api/v1/scripts" do
    let!(:easy_script)   { create(:script, difficulty: 0) }
    let!(:medium_script) { create(:script, difficulty: 1) }

    it "returns all scripts without auth" do
      get "/api/v1/scripts"

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(2)
    end

    it "filters by difficulty" do
      get "/api/v1/scripts?difficulty=0"

      expect(json.all? { |s| s["difficulty"] == "easy" }).to be true
    end
  end

  describe "GET /api/v1/scripts/:id" do
    let!(:script) { create(:script, title: "謀殺謎案") }

    it "returns script detail without auth" do
      get "/api/v1/scripts/#{script.id}"

      expect(response).to have_http_status(:ok)
      expect(json["title"]).to eq("謀殺謎案")
      expect(json).to have_key("description")
      expect(json).to have_key("male_slots")
      expect(json).to have_key("female_slots")
    end

    it "returns 404 for unknown id" do
      get "/api/v1/scripts/999999"
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/scripts (admin only)" do
    it "admin can create a script" do
      post "/api/v1/scripts",
        params: script_params.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:created)
      expect(json["title"]).to eq("新劇本")
    end

    it "non-admin gets 403" do
      post "/api/v1/scripts",
        params: script_params.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(regular_user))

      expect(response).to have_http_status(:forbidden)
    end

    it "unauthenticated gets 401" do
      post "/api/v1/scripts",
        params: script_params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 for invalid params" do
      post "/api/v1/scripts",
        params: { title: "" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "PATCH /api/v1/scripts/:id (admin only)" do
    let!(:script) { create(:script, title: "舊劇本") }

    it "admin can update a script" do
      patch "/api/v1/scripts/#{script.id}",
        params: { title: "更新後劇本" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:ok)
      expect(json["title"]).to eq("更新後劇本")
      expect(script.reload.title).to eq("更新後劇本")
    end

    it "non-admin gets 403" do
      patch "/api/v1/scripts/#{script.id}",
        params: { title: "竊改" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(regular_user))

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for unknown id" do
      patch "/api/v1/scripts/999999",
        params: { title: "x" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:not_found)
    end
  end
end
