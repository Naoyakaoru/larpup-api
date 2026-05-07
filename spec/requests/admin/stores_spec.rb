require "rails_helper"

RSpec.describe "Admin::Stores", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/admin/stores" do
    let!(:store_a) { create(:store, name: "Alpha") }
    let!(:store_b) { create(:store, name: "Beta") }

    it "returns all stores for admin" do
      get "/api/v1/admin/stores", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(2)
      expect(json.map { |s| s["name"] }).to contain_exactly("Alpha", "Beta")
    end

    it "returns 403 for non-admin" do
      get "/api/v1/admin/stores", headers: auth_header(regular_user)

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/admin/stores"

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/admin/stores" do
    let(:owner) { create(:user) }

    it "creates a store with valid params" do
      post "/api/v1/admin/stores",
           params: { name: "New Store", owner_id: owner.id },
           headers: auth_header(admin)

      expect(response).to have_http_status(:created)
      expect(json["name"]).to eq("New Store")
      expect(json["owner"]["id"]).to eq(owner.id)
      expect(json["owner"]["handle"]).to eq(owner.handle)
    end

    it "returns owner details in response" do
      post "/api/v1/admin/stores",
           params: { name: "My Store", owner_id: owner.id },
           headers: auth_header(admin)

      expect(json["owner"]["nickname"]).to eq(owner.nickname)
    end

    it "returns 422 without a name" do
      post "/api/v1/admin/stores",
           params: { owner_id: owner.id },
           headers: auth_header(admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to include("Name can't be blank")
    end

    it "returns 422 without an owner" do
      post "/api/v1/admin/stores",
           params: { name: "No Owner Store" },
           headers: auth_header(admin)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to include("Owner must exist")
    end

    it "returns 403 for non-admin" do
      post "/api/v1/admin/stores",
           params: { name: "Store", owner_id: owner.id },
           headers: auth_header(regular_user)

      expect(response).to have_http_status(:forbidden)
    end
  end
end
