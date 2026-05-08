require "rails_helper"

RSpec.describe "Addresses", type: :request do
  let(:user)  { create(:user) }
  let(:admin) { create(:user, :admin) }
  let(:json)  { JSON.parse(response.body) }

  describe "GET /api/v1/addresses" do
    let!(:taipei)  { create(:address, name: "台北場館", region: "taipei_city") }
    let!(:taichung) { create(:address, name: "台中場館", region: "taichung") }
    let!(:deleted) { create(:address, name: "舊場館", region: "taipei_city", deleted_at: 1.day.ago) }

    it "returns active addresses ordered by name without auth" do
      get "/api/v1/addresses"

      expect(response).to have_http_status(:ok)
      names = json.map { |a| a["name"] }
      expect(names).to contain_exactly("台北場館", "台中場館")
      expect(names).not_to include("舊場館")
    end

    it "filters by name with q param" do
      get "/api/v1/addresses", params: { q: "台北" }

      expect(response).to have_http_status(:ok)
      expect(json.length).to eq(1)
      expect(json.first["name"]).to eq("台北場館")
    end

    it "returns English region key" do
      get "/api/v1/addresses"

      taipei_json = json.find { |a| a["name"] == "台北場館" }
      expect(taipei_json["region"]).to eq("taipei_city")
    end

    context "with version_id param" do
      let(:store)   { create(:store) }
      let(:script)  { create(:script) }
      let(:version) { create(:script_version, script: script, store: store) }
      let!(:version_addr) { create(:address, name: "版本場館") }
      let!(:store_addr)   { create(:address, name: "店家場館") }
      let!(:other_addr)   { create(:address, name: "其他場館") }

      before do
        version.addresses << version_addr
        store.addresses << store_addr
      end

      it "orders version addresses first, then store addresses, then others" do
        get "/api/v1/addresses", params: { version_id: version.id }

        expect(response).to have_http_status(:ok)
        names = json.map { |a| a["name"] }
        expect(names.index("版本場館")).to be < names.index("店家場館")
        expect(names.index("店家場館")).to be < names.index("其他場館")
      end
    end
  end

  describe "POST /api/v1/addresses" do
    let(:store_owner) { create(:user) }
    let!(:store)      { create(:store, owner: store_owner) }
    let(:valid_params) { { name: "新場館", region: "taipei_city", address: "台北市信義區" } }

    it "creates an address when caller owns a store" do
      post "/api/v1/addresses", params: valid_params, headers: auth_header(store_owner)

      expect(response).to have_http_status(:created)
      expect(json["name"]).to eq("新場館")
      expect(json["region"]).to eq("taipei_city")
    end

    it "allows admin to create without owning a store" do
      post "/api/v1/addresses", params: valid_params, headers: auth_header(admin)
      expect(response).to have_http_status(:created)
    end

    it "returns 403 for user with no store" do
      post "/api/v1/addresses", params: valid_params, headers: auth_header(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "writes an audit log on creation" do
      expect {
        post "/api/v1/addresses", params: valid_params, headers: auth_header(store_owner)
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("created")
    end

    it "auto-links to store when store_id provided and user is owner" do
      post "/api/v1/addresses", params: valid_params.merge(store_id: store.id), headers: auth_header(store_owner)

      expect(response).to have_http_status(:created)
      expect(store.addresses.reload.map(&:name)).to include("新場館")
    end

    it "returns warning when store_id is given but not found or inaccessible" do
      other_store = create(:store)
      post "/api/v1/addresses", params: valid_params.merge(store_id: other_store.id), headers: auth_header(store_owner)

      expect(response).to have_http_status(:created)
      expect(json["warning"]).to eq("store_id not found or not accessible")
      expect(other_store.addresses.reload).to be_empty
    end

    it "returns 422 when name is missing" do
      post "/api/v1/addresses", params: { region: "taipei_city" }, headers: auth_header(store_owner)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to include(a_string_matching(/Name/))
    end

    it "returns 422 when region is missing" do
      post "/api/v1/addresses", params: { name: "新場館" }, headers: auth_header(store_owner)

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to include(a_string_matching(/Region/))
    end

    it "returns 401 without auth" do
      post "/api/v1/addresses", params: valid_params

      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/addresses/:id" do
    let(:store_owner) { create(:user) }
    let!(:store)      { create(:store, owner: store_owner) }
    let!(:address)    { create(:address, name: "原場館", region: "taipei_city", address: "原地址") }

    before { store.addresses << address }

    context "as admin" do
      it "can update all fields" do
        patch "/api/v1/addresses/#{address.id}",
              params: { name: "新場館", address: "新地址", region: "taichung" },
              headers: auth_header(admin)

        expect(response).to have_http_status(:ok)
        expect(json["name"]).to eq("新場館")
        expect(json["region"]).to eq("taichung")
      end

      it "writes audit log only when fields change" do
        patch "/api/v1/addresses/#{address.id}",
              params: { name: "新場館" },
              headers: auth_header(admin)

        expect(AuditLog.last.metadata["changes"]).to include("name")
      end
    end

    context "as store owner" do
      it "can only update name, not address text or region" do
        patch "/api/v1/addresses/#{address.id}",
              params: { name: "新場館", address: "攻擊地址", region: "kaohsiung" },
              headers: auth_header(store_owner)

        expect(response).to have_http_status(:ok)
        expect(json["name"]).to eq("新場館")
        expect(json["region"]).to eq("taipei_city")
        expect(address.reload.address).to eq("原地址")
      end
    end

    it "returns 403 for user with no relation to this address" do
      patch "/api/v1/addresses/#{address.id}", params: { name: "x" }, headers: auth_header(user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 404 for unknown address" do
      patch "/api/v1/addresses/999999", params: { name: "x" }, headers: auth_header(admin)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 401 without auth" do
      patch "/api/v1/addresses/#{address.id}", params: { name: "x" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
