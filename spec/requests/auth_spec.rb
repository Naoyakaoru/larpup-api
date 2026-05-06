require "rails_helper"

RSpec.describe "Auth", type: :request do
  describe "POST /api/v1/auth/register" do
    let(:params) do
      { email: "new@example.com", password: "password123", nickname: "NewUser", gender: "female" }
    end

    it "creates a user and returns a token" do
      post "/api/v1/auth/register", params: params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:created)
      body = JSON.parse(response.body)
      expect(body["token"]).to be_present
      expect(body["user"]["email"]).to eq("new@example.com")
    end

    it "returns errors for duplicate email" do
      create(:user, email: "new@example.com")
      post "/api/v1/auth/register", params: params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "DELETE /api/v1/auth/logout" do
    it "returns success with valid token" do
      user = create(:user)
      delete "/api/v1/auth/logout", headers: auth_header(user)

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["message"]).to be_present
    end

    it "returns 401 without token" do
      delete "/api/v1/auth/logout"
      expect(response).to have_http_status(:unauthorized)
    end
  end

  describe "POST /api/v1/auth/login" do
    let!(:user) { create(:user, email: "test@example.com", password_digest: BCrypt::Password.create("password123")) }

    it "returns token on valid credentials" do
      post "/api/v1/auth/login",
        params: { email: "test@example.com", password: "password123" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body)["token"]).to be_present
    end

    it "returns 401 on wrong password" do
      post "/api/v1/auth/login",
        params: { email: "test@example.com", password: "wrong" }.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end
  end
end
