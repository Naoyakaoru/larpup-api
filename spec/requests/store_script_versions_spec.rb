require "rails_helper"

RSpec.describe "StoreScriptVersions", type: :request do
  let(:owner)        { create(:user) }
  let(:other_user)   { create(:user) }
  let(:admin)        { create(:user, :admin) }
  let!(:store)       { create(:store, owner: owner) }
  let!(:script)      { create(:script) }
  let!(:base_version) { create(:script_version, script: script, store: nil) }

  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/stores/:store_id/script_versions" do
    let!(:version) { create(:script_version, script: script, store: store, price: 500, available: true) }
    let!(:unavailable) { create(:script_version, script: script, store: store, price: 200, available: false) }

    it "returns all versions for store owner (including unavailable)" do
      get "/api/v1/stores/#{store.id}/script_versions", headers: auth_header(owner)

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(2)
    end

    it "returns 403 for non-owner" do
      get "/api/v1/stores/#{store.id}/script_versions", headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "admin can access any store's versions" do
      get "/api/v1/stores/#{store.id}/script_versions", headers: auth_header(admin)
      expect(response).to have_http_status(:ok)
    end

    it "returns 401 without auth" do
      get "/api/v1/stores/#{store.id}/script_versions"
      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 404 for unknown store" do
      get "/api/v1/stores/999999/script_versions", headers: auth_header(owner)
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "POST /api/v1/stores/:store_id/script_versions (existing script)" do
    it "creates a store version linked to an existing script" do
      expect {
        post "/api/v1/stores/#{store.id}/script_versions",
          params: { script_id: script.id, price: 500, version_name: "標準版" }.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))
      }.to change(ScriptVersion, :count).by(1)

      expect(response).to have_http_status(:created)
      expect(json["price"]).to eq(500)
      expect(json["version_name"]).to eq("標準版")
      expect(json["script"]["id"]).to eq(script.id)
    end

    it "writes an audit log on creation" do
      expect {
        post "/api/v1/stores/#{store.id}/script_versions",
          params: { script_id: script.id, price: 400 }.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("created")
    end

    it "returns 403 for non-owner" do
      post "/api/v1/stores/#{store.id}/script_versions",
        params: { script_id: script.id, price: 500 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST /api/v1/stores/:store_id/script_versions (new script)" do
    let(:new_script_params) do
      {
        title: "全新劇本",
        difficulty: 1,
        male_slots: 2,
        female_slots: 2,
        any_slots: 0,
        genres: [ 0 ],
        price: 600
      }
    end

    it "creates both a new script and a store version" do
      expect {
        post "/api/v1/stores/#{store.id}/script_versions",
          params: new_script_params.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))
      }.to change(Script, :count).by(1).and change(ScriptVersion, :count).by(2)

      expect(response).to have_http_status(:created)
    end

    it "creates the new script with pending status" do
      post "/api/v1/stores/#{store.id}/script_versions",
        params: new_script_params.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))

      new_script = Script.find(json["script"]["id"])
      expect(new_script.status).to eq("pending")
    end

    it "creates a base version (store_id nil) for the new script" do
      post "/api/v1/stores/#{store.id}/script_versions",
        params: new_script_params.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))

      new_script = Script.find(json["script"]["id"])
      expect(new_script.script_versions.where(store_id: nil).count).to eq(1)
    end
  end

  describe "PATCH /api/v1/stores/:store_id/script_versions/:id" do
    let!(:version) { create(:script_version, script: script, store: store, price: 500, available: true) }

    it "owner can update price and availability" do
      patch "/api/v1/stores/#{store.id}/script_versions/#{version.id}",
        params: { price: 450, available: false }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))

      expect(response).to have_http_status(:ok)
      expect(json["price"]).to eq(450)
      expect(json["available"]).to be false
    end

    it "writes an audit log when changes are made" do
      expect {
        patch "/api/v1/stores/#{store.id}/script_versions/#{version.id}",
          params: { price: 600 }.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("updated")
    end

    it "does not write audit log when nothing changes" do
      expect {
        patch "/api/v1/stores/#{store.id}/script_versions/#{version.id}",
          params: { price: 500 }.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))
      }.not_to change(AuditLog, :count)
    end

    it "returns 403 for non-owner" do
      patch "/api/v1/stores/#{store.id}/script_versions/#{version.id}",
        params: { price: 100 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for version belonging to another store" do
      other_store = create(:store)
      other_version = create(:script_version, script: script, store: other_store, price: 300)

      patch "/api/v1/stores/#{store.id}/script_versions/#{other_version.id}",
        params: { price: 100 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(owner))

      expect(response).to have_http_status(:not_found)
    end
  end
end
