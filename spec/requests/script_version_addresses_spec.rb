require "rails_helper"

RSpec.describe "ScriptVersionAddresses", type: :request do
  let(:owner)      { create(:user) }
  let(:other_user) { create(:user) }
  let(:admin)      { create(:user, :admin) }
  let(:store)      { create(:store, owner: owner) }
  let(:script)     { create(:script) }
  let(:version)    { create(:script_version, script: script, store: store) }
  let(:json)       { JSON.parse(response.body) }

  let(:base_path) { "/api/v1/stores/#{store.id}/script_versions/#{version.id}/addresses" }

  describe "GET addresses" do
    let!(:linked)   { create(:address, name: "版本場館") }
    let!(:unlinked) { create(:address, name: "未連結") }

    before { version.addresses << linked }

    it "returns only addresses linked to this version" do
      get base_path, headers: auth_header(owner)

      expect(response).to have_http_status(:ok)
      expect(json.map { |a| a["name"] }).to contain_exactly("版本場館")
    end

    it "returns 403 for non-owner" do
      get base_path, headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "POST — link address to version" do
    let!(:address) { create(:address) }

    it "links an address to the script version" do
      post base_path, params: { address_id: address.id }, headers: auth_header(owner)

      expect(response).to have_http_status(:created)
      expect(version.addresses.reload).to include(address)
    end

    it "is idempotent" do
      version.addresses << address

      post base_path, params: { address_id: address.id }, headers: auth_header(owner)

      expect(response).to have_http_status(:created)
      expect(version.addresses.count).to eq(1)
    end

    it "returns 404 for unknown address" do
      post base_path, params: { address_id: 999999 }, headers: auth_header(owner)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-owner" do
      post base_path, params: { address_id: address.id }, headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE — unlink address from version" do
    let!(:address) { create(:address) }

    before { version.addresses << address }

    it "unlinks the address" do
      delete "#{base_path}/#{address.id}", headers: auth_header(owner)

      expect(response).to have_http_status(:no_content)
      expect(version.addresses.reload).not_to include(address)
    end

    it "does not destroy the address itself" do
      expect {
        delete "#{base_path}/#{address.id}", headers: auth_header(owner)
      }.not_to change(Address, :count)
    end

    it "returns 404 when address is not linked to this version" do
      other = create(:address)
      delete "#{base_path}/#{other.id}", headers: auth_header(owner)
      expect(response).to have_http_status(:not_found)
    end
  end
end
