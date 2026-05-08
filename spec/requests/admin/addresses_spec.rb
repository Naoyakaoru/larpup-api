require "rails_helper"

RSpec.describe "Admin::Addresses", type: :request do
  let(:admin)        { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:json)         { JSON.parse(response.body) }

  describe "GET /api/v1/admin/addresses" do
    let!(:active)  { create(:address, name: "活躍場館") }
    let!(:deleted) { create(:address, name: "刪除場館", deleted_at: 1.day.ago) }

    it "returns all addresses including deleted" do
      get "/api/v1/admin/addresses", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      names = json.map { |a| a["name"] }
      expect(names).to include("活躍場館", "刪除場館")
    end

    it "returns 403 for non-admin" do
      get "/api/v1/admin/addresses", headers: auth_header(regular_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/admin/addresses"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "DELETE /api/v1/admin/addresses/:id" do
    let!(:address) { create(:address) }

    it "soft-deletes the address" do
      delete "/api/v1/admin/addresses/#{address.id}", headers: auth_header(admin)

      expect(response).to have_http_status(:no_content)
      expect(address.reload.deleted_at).not_to be_nil
    end

    it "writes an audit log" do
      expect {
        delete "/api/v1/admin/addresses/#{address.id}", headers: auth_header(admin)
      }.to change(AuditLog, :count).by(1)

      expect(AuditLog.last.action).to eq("deleted")
    end

    it "does not destroy the record" do
      expect {
        delete "/api/v1/admin/addresses/#{address.id}", headers: auth_header(admin)
      }.not_to change(Address, :count)
    end

    it "returns 422 when already deleted" do
      address.update_column(:deleted_at, 1.day.ago)

      delete "/api/v1/admin/addresses/#{address.id}", headers: auth_header(admin)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 404 for unknown address" do
      delete "/api/v1/admin/addresses/999999", headers: auth_header(admin)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-admin" do
      delete "/api/v1/admin/addresses/#{address.id}", headers: auth_header(regular_user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
