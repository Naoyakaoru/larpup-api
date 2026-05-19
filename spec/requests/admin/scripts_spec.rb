require "rails_helper"

RSpec.describe "Admin::Scripts", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:regular_user) { create(:user) }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/admin/scripts" do
    let!(:pending_script)  { create(:script, status: :pending) }
    let!(:approved_script) { create(:script, status: :approved) }
    let!(:rejected_script) { create(:script, status: :rejected) }

    it "returns all scripts for admin, paginated, pending first" do
      get "/api/v1/admin/scripts", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json["scripts"].length).to eq(3)
      expect(json["total"]).to eq(3)
      expect(json["pending_count"]).to eq(1)
      expect(json["scripts"].first["status"]).to eq("pending")
    end

    it "includes status field in each script" do
      get "/api/v1/admin/scripts", headers: auth_header(admin)

      statuses = json["scripts"].map { |s| s["status"] }
      expect(statuses).to contain_exactly("pending", "approved", "rejected")
    end

    it "returns 403 for non-admin" do
      get "/api/v1/admin/scripts", headers: auth_header(regular_user)
      expect(response).to have_http_status(:forbidden)
    end

    it "returns 401 without auth" do
      get "/api/v1/admin/scripts"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/admin/scripts/:id/approve" do
    let!(:script) { create(:script, status: :pending) }

    it "approves a pending script" do
      patch "/api/v1/admin/scripts/#{script.id}/approve", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("approved")
      expect(script.reload.status).to eq("approved")
    end

    it "can approve an already-rejected script" do
      script.update!(status: :rejected)
      patch "/api/v1/admin/scripts/#{script.id}/approve", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("approved")
    end

    it "returns 404 for unknown script" do
      patch "/api/v1/admin/scripts/999999/approve", headers: auth_header(admin)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-admin" do
      patch "/api/v1/admin/scripts/#{script.id}/approve", headers: auth_header(regular_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/admin/scripts/:id/reject" do
    let!(:script) { create(:script, status: :pending) }

    it "rejects a pending script" do
      patch "/api/v1/admin/scripts/#{script.id}/reject", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("rejected")
      expect(script.reload.status).to eq("rejected")
    end

    it "can reject an approved script" do
      script.update!(status: :approved)
      patch "/api/v1/admin/scripts/#{script.id}/reject", headers: auth_header(admin)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("rejected")
    end

    it "returns 404 for unknown script" do
      patch "/api/v1/admin/scripts/999999/reject", headers: auth_header(admin)
      expect(response).to have_http_status(:not_found)
    end

    it "returns 403 for non-admin" do
      patch "/api/v1/admin/scripts/#{script.id}/reject", headers: auth_header(regular_user)
      expect(response).to have_http_status(:forbidden)
    end
  end
end
