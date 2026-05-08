require "rails_helper"

RSpec.describe "StoreAddresses", type: :request do
  let(:owner)       { create(:user) }
  let(:other_user)  { create(:user) }
  let(:admin)       { create(:user, :admin) }
  let(:store)       { create(:store, owner: owner) }
  let(:json)        { JSON.parse(response.body) }

  describe "GET /api/v1/stores/:store_id/addresses" do
    let!(:linked)   { create(:address, name: "連結場館") }
    let!(:unlinked) { create(:address, name: "未連結") }

    before { store.addresses << linked }

    it "returns only addresses linked to this store" do
      get "/api/v1/stores/#{store.id}/addresses", headers: auth_header(owner)

      expect(response).to have_http_status(:ok)
      expect(json.map { |a| a["name"] }).to contain_exactly("連結場館")
    end

    it "returns 403 for non-owner" do
      get "/api/v1/stores/#{store.id}/addresses", headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "allows admin access" do
      get "/api/v1/stores/#{store.id}/addresses", headers: auth_header(admin)
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/stores/:store_id/addresses — link existing" do
    let!(:address) { create(:address) }

    it "links an existing address to the store" do
      post "/api/v1/stores/#{store.id}/addresses",
           params: { address_id: address.id },
           headers: auth_header(owner)

      expect(response).to have_http_status(:created)
      expect(store.addresses.reload).to include(address)
    end

    it "is idempotent — linking twice does not error" do
      store.addresses << address

      post "/api/v1/stores/#{store.id}/addresses",
           params: { address_id: address.id },
           headers: auth_header(owner)

      expect(response).to have_http_status(:created)
      expect(store.addresses.count).to eq(1)
    end

    it "returns 404 for unknown address" do
      post "/api/v1/stores/#{store.id}/addresses",
           params: { address_id: 999999 },
           headers: auth_header(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-owner" do
      post "/api/v1/stores/#{store.id}/addresses",
           params: { address_id: address.id },
           headers: auth_header(other_user)

      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/stores/:store_id/addresses/:id — unlink" do
    let!(:address) { create(:address) }

    before { store.addresses << address }

    it "unlinks address from store" do
      delete "/api/v1/stores/#{store.id}/addresses/#{address.id}", headers: auth_header(owner)

      expect(response).to have_http_status(:no_content)
      expect(store.addresses.reload).not_to include(address)
    end

    it "does not destroy the address itself" do
      expect {
        delete "/api/v1/stores/#{store.id}/addresses/#{address.id}", headers: auth_header(owner)
      }.not_to change(Address, :count)
    end

    it "returns 404 when address is not linked to this store" do
      other_address = create(:address)
      delete "/api/v1/stores/#{store.id}/addresses/#{other_address.id}", headers: auth_header(owner)

      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-owner" do
      delete "/api/v1/stores/#{store.id}/addresses/#{address.id}", headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
