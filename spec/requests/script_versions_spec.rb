require "rails_helper"

RSpec.describe "ScriptVersions", type: :request do
  let(:json) { JSON.parse(response.body) }
  let!(:script) { create(:script) }
  let!(:store_a) { create(:store, name: "Alpha") }
  let!(:store_b) { create(:store, name: "Beta") }

  let!(:base_version) { create(:script_version, script: script, store: nil) }
  let!(:version_a) do
    create(:script_version, script: script, store: store_a,
           price: 500, version_name: "標準版", duration_override: 3, available: true)
  end
  let!(:version_b) do
    create(:script_version, script: script, store: store_b,
           price: 450, version_name: nil, duration_override: nil, available: true)
  end
  let!(:unavailable_version) do
    create(:script_version, script: script, store: store_a,
           price: 300, available: false)
  end

  describe "GET /api/v1/scripts/:script_id/versions" do
    it "returns store versions without auth" do
      get "/api/v1/scripts/#{script.id}/versions"

      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
    end

    it "excludes the base version (store_id nil)" do
      get "/api/v1/scripts/#{script.id}/versions"
      expect(json.none? { |v| v["store"].nil? }).to be true
    end

    it "excludes unavailable versions" do
      get "/api/v1/scripts/#{script.id}/versions"
      expect(json.length).to eq(2)
    end

    it "returns store, price, version_name, and resolved duration" do
      get "/api/v1/scripts/#{script.id}/versions"

      va = json.find { |v| v["store"]["name"] == "Alpha" }
      expect(va["price"]).to eq(500)
      expect(va["version_name"]).to eq("標準版")
      expect(va["duration"]).to eq(3)
      expect(va["store"]["id"]).to eq(store_a.id)
    end

    it "falls back to script duration when version has no duration_override" do
      script.update!(duration: 4)
      get "/api/v1/scripts/#{script.id}/versions"

      vb = json.find { |v| v["store"]["name"] == "Beta" }
      expect(vb["duration"]).to eq(4)
    end

    it "returns versions sorted by store name" do
      get "/api/v1/scripts/#{script.id}/versions"
      names = json.map { |v| v["store"]["name"] }
      expect(names).to eq(names.sort)
    end

    it "returns 404 for unknown script" do
      get "/api/v1/scripts/999999/versions"
      expect(response).to have_http_status(:not_found)
    end
  end
end
