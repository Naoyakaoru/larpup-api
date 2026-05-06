require "rails_helper"

RSpec.describe "Users", type: :request do
  let(:user) { create(:user, nickname: "Tester", gender: "female") }
  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/users/me" do
    it "returns current user profile" do
      get "/api/v1/users/me", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(json["email"]).to eq(user.email)
      expect(json["nickname"]).to eq("Tester")
      expect(json["gender"]).to eq("female")
      expect(json).to have_key("avatar_url")
      expect(json).to have_key("is_admin")
    end

    it "returns 401 without token" do
      get "/api/v1/users/me"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "PATCH /api/v1/users/me" do
    it "updates nickname" do
      patch "/api/v1/users/me",
        params: { nickname: "NewName" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:ok)
      expect(json["nickname"]).to eq("NewName")
      expect(user.reload.nickname).to eq("NewName")
    end

    it "updates password" do
      patch "/api/v1/users/me",
        params: { password: "newpass123", password_confirmation: "newpass123" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate("newpass123")).to be_truthy
    end

    it "returns 422 when password confirmation mismatches" do
      patch "/api/v1/users/me",
        params: { password: "newpass123", password_confirmation: "wrong" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "ignores non-permitted fields like email" do
      original_email = user.email
      patch "/api/v1/users/me",
        params: { email: "hacker@evil.com" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(user.reload.email).to eq(original_email)
    end
  end

  describe "GET /api/v1/users/me/events" do
    let(:script) { create(:script) }

    it "returns hosted events" do
      event = create(:event, host: user, script: script)
      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(json["hosted"].map { |e| e["id"] }).to include(event.id)
    end

    it "returns joined events" do
      host = create(:user)
      event = create(:event, host: host, script: script)
      create(:event_member, :confirmed, event: event, user: user)

      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(json["joined"].map { |e| e["id"] }).to include(event.id)
    end

    it "does not return events hosted by others in hosted list" do
      other = create(:user)
      create(:event, host: other, script: script)

      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(json["hosted"]).to be_empty
    end

    it "returns 401 without token" do
      get "/api/v1/users/me/events"
      expect(response).to have_http_status(:unauthorized)
    end
  end
end
