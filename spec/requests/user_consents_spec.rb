require 'rails_helper'

RSpec.describe "UserConsents", type: :request do
  let(:user) { create(:user) }
  let(:headers) { auth_header(user) }

  describe "POST /api/v1/user_consents" do
    let(:valid_params) do
      {
        consent_type: "privacy_policy",
        consent_version: "2026-05",
        accepted: true,
        source: "web_signup"
      }
    end

    it "creates a new user consent record" do
      expect {
        post "/api/v1/user_consents", params: valid_params, headers: headers
      }.to change(UserConsent, :count).by(1)

      expect(response).to have_http_status(:created)
      
      consent = UserConsent.last
      expect(consent.user).to eq(user)
      expect(consent.consent_type).to eq("privacy_policy")
      expect(consent.consent_version).to eq("2026-05")
      expect(consent.accepted).to eq(true)
      expect(consent.source).to eq("web_signup")
      expect(consent.ip_address).to be_present
    end

    it "returns unprocessable_entity for invalid params" do
      expect {
        post "/api/v1/user_consents", params: { consent_type: "invalid_type" }, headers: headers
      }.not_to change(UserConsent, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "prevents duplicate consent for the same type and version" do
      create(:user_consent, user: user, consent_type: "privacy_policy", consent_version: "2026-05")

      expect {
        post "/api/v1/user_consents", params: valid_params, headers: headers
      }.not_to change(UserConsent, :count)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "GET /api/v1/user_consents" do
    before do
      create(:user_consent, user: user, consent_type: "privacy_policy", consent_version: "2026-05", accepted_at: 1.day.ago)
      create(:user_consent, user: user, consent_type: "terms_of_service", consent_version: "2026-05", accepted_at: Time.current)
    end

    it "returns the user's consent records ordered by accepted_at descending" do
      get "/api/v1/user_consents", headers: headers

      expect(response).to have_http_status(:ok)
      json = JSON.parse(response.body)
      expect(json.size).to eq(2)
      expect(json.first["consent_type"]).to eq("terms_of_service")
      expect(json.last["consent_type"]).to eq("privacy_policy")
    end
  end
end
