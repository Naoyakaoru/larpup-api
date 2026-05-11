require "rails_helper"

RSpec.describe "Sso", type: :request do
  let(:json) { JSON.parse(response.body) }

  # ─── Helpers ───────────────────────────────────────────────────

  # Stub Google tokeninfo endpoint
  def stub_google_token(sub: "google-sub-123", email: "g@example.com", name: "Google User", valid: true)
    client_id = ENV.fetch("GOOGLE_CLIENT_ID", "test-client-id")
    body = valid ? { "sub" => sub, "email" => email, "name" => name, "aud" => client_id }.to_json
                 : { "error" => "invalid_token" }.to_json
    stub_request(:get, /oauth2\.googleapis\.com\/tokeninfo/)
      .to_return(status: valid ? 200 : 400, body: body, headers: { "Content-Type" => "application/json" })
  end

  # Stub LINE token exchange + profile endpoints
  def stub_line(uid: "line-uid-abc", display_name: "LINE User", email: "l@example.com", valid: true)
    if valid
      token_body = { "access_token" => "fake_access", "id_token" => build_line_id_token(email) }.to_json
      stub_request(:post, "https://api.line.me/oauth2/v2.1/token")
        .to_return(status: 200, body: token_body, headers: { "Content-Type" => "application/json" })
      profile_body = { "userId" => uid, "displayName" => display_name }.to_json
      stub_request(:get, "https://api.line.me/v2/profile")
        .to_return(status: 200, body: profile_body, headers: { "Content-Type" => "application/json" })
    else
      stub_request(:post, "https://api.line.me/oauth2/v2.1/token")
        .to_return(status: 400, body: { "error" => "invalid_grant" }.to_json)
    end
  end

  def build_line_id_token(email)
    payload = Base64.urlsafe_encode64({ "email" => email }.to_json, padding: false)
    "header.#{payload}.sig"
  end

  before { allow(ENV).to receive(:fetch).and_call_original }

  # ─── Google SSO ────────────────────────────────────────────────

  describe "POST /api/v1/auth/sso/google" do
    context "with a valid id_token for an existing user (matched by google_uid)" do
      let!(:user) { create(:user, google_uid: "google-sub-123") }

      it "returns 200 with JWT token" do
        stub_google_token
        post "/api/v1/auth/sso/google",
          params: { id_token: "valid-token" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json["token"]).to be_present
        expect(json["user"]["email"]).to eq(user.email)
      end
    end

    context "with a valid id_token matching by email (binds google_uid)" do
      let!(:user) { create(:user, email: "g@example.com", google_uid: nil) }

      it "returns 200 and updates google_uid" do
        stub_google_token(email: "g@example.com")
        post "/api/v1/auth/sso/google",
          params: { id_token: "valid-token" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(user.reload.google_uid).to eq("google-sub-123")
      end
    end

    context "with a valid id_token for a brand-new user" do
      it "returns 202 with temp_token" do
        stub_google_token
        post "/api/v1/auth/sso/google",
          params: { id_token: "valid-token" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:accepted)
        expect(json["temp_token"]).to be_present
        expect(json["email"]).to eq("g@example.com")
        expect(json["nickname"]).to eq("Google User")
      end
    end

    context "with an invalid id_token" do
      it "returns 401" do
        stub_google_token(valid: false)
        post "/api/v1/auth/sso/google",
          params: { id_token: "bad-token" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── LINE SSO ──────────────────────────────────────────────────

  describe "POST /api/v1/auth/sso/line" do
    context "with a valid code for an existing user (matched by line_uid)" do
      let!(:user) { create(:user, line_uid: "line-uid-abc") }

      it "returns 200 with JWT token" do
        stub_line
        post "/api/v1/auth/sso/line",
          params: { code: "valid-code", redirect_uri: "http://localhost:5173/auth/line/callback" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:ok)
        expect(json["token"]).to be_present
      end
    end

    context "with a valid code for a brand-new user" do
      it "returns 202 with temp_token" do
        stub_line
        post "/api/v1/auth/sso/line",
          params: { code: "valid-code", redirect_uri: "http://localhost:5173/auth/line/callback" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:accepted)
        expect(json["temp_token"]).to be_present
        expect(json["email"]).to eq("l@example.com")
      end
    end

    context "with an invalid code" do
      it "returns 401" do
        stub_line(valid: false)
        post "/api/v1/auth/sso/line",
          params: { code: "bad-code", redirect_uri: "http://localhost:5173/auth/line/callback" }.to_json,
          headers: { "Content-Type" => "application/json" }

        expect(response).to have_http_status(:unauthorized)
      end
    end
  end

  # ─── SSO Register ──────────────────────────────────────────────

  describe "POST /api/v1/auth/sso/register" do
    def valid_temp_token(uid_field: "google_uid", uid: "google-sub-new", email: "new@example.com", nickname: "NewUser", exp: 5.minutes.from_now.to_i)
      JwtAuthenticatable.encode(type: "sso_pending", uid_field: uid_field, uid: uid, email: email, nickname: nickname, exp: exp)
    end

    it "creates a user and returns 201 with JWT" do
      post "/api/v1/auth/sso/register",
        params: { temp_token: valid_temp_token, gender: "female", nickname: "MyName" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      expect(json["token"]).to be_present
      expect(json["user"]["gender"]).to eq("female")
      expect(json["user"]["nickname"]).to eq("MyName")
      user = User.find_by(email: "new@example.com")
      expect(user).to be_present
      expect(user.google_uid).to eq("google-sub-new")
    end

    it "uses the nickname from payload if not provided in params" do
      post "/api/v1/auth/sso/register",
        params: { temp_token: valid_temp_token, gender: "male" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      expect(json["user"]["nickname"]).to eq("NewUser")
    end

    it "returns 401 when temp_token is expired" do
      expired = valid_temp_token(exp: 1.minute.ago.to_i)
      post "/api/v1/auth/sso/register",
        params: { temp_token: expired, gender: "female" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 401 when temp_token has wrong type" do
      wrong_type = JwtAuthenticatable.encode(type: "normal", user_id: 99)
      post "/api/v1/auth/sso/register",
        params: { temp_token: wrong_type, gender: "female" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "returns 422 when gender is invalid" do
      post "/api/v1/auth/sso/register",
        params: { temp_token: valid_temp_token, gender: "unknown" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["errors"]).to be_present
    end
  end
end
