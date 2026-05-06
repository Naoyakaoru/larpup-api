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
      expect(json).to have_key("show_hosted_events")
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

    it "updates show_hosted_events" do
      patch "/api/v1/users/me",
        params: { show_hosted_events: true }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:ok)
      expect(json["show_hosted_events"]).to be true
      expect(user.reload.show_hosted_events).to be true
    end

    it "updates handle to a valid custom value" do
      patch "/api/v1/users/me",
        params: { handle: "hsuan_123" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:ok)
      expect(json["handle"]).to eq("hsuan_123")
    end

    it "returns 422 for invalid handle format" do
      patch "/api/v1/users/me",
        params: { handle: "UPPERCASE!" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "returns 422 for duplicate handle" do
      other = create(:user, handle: "taken_handle")
      patch "/api/v1/users/me",
        params: { handle: "taken_handle" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(user))

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/users/me/events" do
    let(:script) { create(:script) }
    let(:script_version) { create(:script_version, script: script) }

    it "returns hosted events" do
      event = create(:event, host: user, script_version: script_version)
      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(json["hosted"].map { |e| e["id"] }).to include(event.id)
    end

    it "returns joined events" do
      host = create(:user)
      event = create(:event, host: host, script_version: script_version)
      create(:event_member, :confirmed, event: event, user: user)

      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(json["joined"].map { |e| e["id"] }).to include(event.id)
    end

    it "does not return events hosted by others in hosted list" do
      other = create(:user)
      create(:event, host: other, script_version: script_version)

      get "/api/v1/users/me/events", headers: auth_header(user)

      expect(json["hosted"]).to be_empty
    end

    it "returns 401 without token" do
      get "/api/v1/users/me/events"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "GET /api/v1/users/:handle" do
    let(:script) { create(:script) }
    let(:script_version) { create(:script_version, script: script) }

    it "returns public profile without hosted_events when show_hosted_events is false" do
      get "/api/v1/users/#{user.handle}"

      expect(response).to have_http_status(:ok)
      expect(json["handle"]).to eq(user.handle)
      expect(json["nickname"]).to eq("Tester")
      expect(json).not_to have_key("email")
      expect(json).not_to have_key("hosted_events")
    end

    it "returns hosted_events when show_hosted_events is true" do
      user.update!(show_hosted_events: true)
      event = create(:event, host: user, script_version: script_version)

      get "/api/v1/users/#{user.handle}"

      expect(response).to have_http_status(:ok)
      expect(json["hosted_events"].map { |e| e["id"] }).to include(event.id)
    end

    it "does not include cancelled events in hosted_events" do
      user.update!(show_hosted_events: true)
      create(:event, :cancelled, host: user, script_version: script_version)

      get "/api/v1/users/#{user.handle}"

      expect(json["hosted_events"]).to be_empty
    end

    it "does not expose joined events publicly" do
      host = create(:user)
      event = create(:event, host: host, script_version: script_version)
      create(:event_member, :confirmed, event: event, user: user)

      get "/api/v1/users/#{user.handle}"

      expect(json).not_to have_key("joined_events")
    end

    it "returns 404 for non-existent handle" do
      get "/api/v1/users/doesnotexist"
      expect(response).to have_http_status(:not_found)
    end
  end
end
