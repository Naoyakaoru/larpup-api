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

  describe "POST /api/v1/admin/scripts/bulk_import" do
    let(:base_row) do
      {
        title: "測試劇本",
        difficulty: "medium",
        genres: [ 0, 3 ],
        male_slots: 3,
        female_slots: 3,
        any_slots: 0,
        duration: "3.0",
        description: "簡介",
        publisher: "某工作室",
        qiandao_id: "abc123",
        rating: "9.1",
        wish_count: "48000",
        cover_image_id: "cover.jpg"
      }
    end

    it "creates new scripts and saves wish_count in metadata" do
      post "/api/v1/admin/scripts/bulk_import",
        params: { scripts: [ base_row ] }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:ok)
      expect(json["created"]).to eq(1)
      expect(json["skipped"]).to eq(0)

      s = Script.find_by!(title: "測試劇本")
      expect(s.metadata["qiandao_wish_count"]).to eq(48000)
      expect(s.metadata["qiandao_rating"]).to eq(9.1)
      expect(s.metadata["qiandao_cover_id"]).to eq("cover.jpg")
    end

    it "updates metadata for existing scripts instead of skipping" do
      existing = create(:script, title: "測試劇本", metadata: { qiandao_wish_count: 100 })

      post "/api/v1/admin/scripts/bulk_import",
        params: { scripts: [ base_row ] }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(response).to have_http_status(:ok)
      expect(json["skipped"]).to eq(1)
      expect(json["created"]).to eq(0)
      expect(existing.reload.metadata["qiandao_wish_count"]).to eq(48000)
    end

    it "preserves existing metadata keys not in the import row" do
      existing = create(:script, title: "測試劇本", metadata: { some_custom_key: "keep_me", qiandao_wish_count: 100 })

      post "/api/v1/admin/scripts/bulk_import",
        params: { scripts: [ base_row ] }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(existing.reload.metadata["some_custom_key"]).to eq("keep_me")
    end

    it "handles mixed new and existing scripts" do
      create(:script, title: "已存在劇本")
      new_row      = base_row.merge(title: "全新劇本")
      existing_row = base_row.merge(title: "已存在劇本")

      post "/api/v1/admin/scripts/bulk_import",
        params: { scripts: [ new_row, existing_row ] }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(admin))

      expect(json["created"]).to eq(1)
      expect(json["skipped"]).to eq(1)
    end

    it "returns 403 for non-admin" do
      post "/api/v1/admin/scripts/bulk_import",
        params: { scripts: [ base_row ] }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(regular_user))

      expect(response).to have_http_status(:forbidden)
    end
  end
end
