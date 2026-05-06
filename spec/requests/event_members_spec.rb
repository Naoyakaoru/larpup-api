require "rails_helper"

RSpec.describe "EventMembers", type: :request do
  let(:host) { create(:user, :male) }
  let(:applicant) { create(:user, :female) }
  let(:script) { create(:script, male_slots: 2, female_slots: 2) }
  let!(:event) { create(:event, script: script, host: host) }
  let!(:member) { create(:event_member, event: event, user: applicant) }

  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/events/:event_id/members" do
    it "returns member list to host" do
      get "/api/v1/events/#{event.id}/members", headers: auth_header(host)

      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
    end

    it "forbids non-host" do
      get "/api/v1/events/#{event.id}/members", headers: auth_header(applicant)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "PATCH /api/v1/events/:event_id/members/:id" do
    it "host can confirm a pending member" do
      patch "/api/v1/events/#{event.id}/members/#{member.id}",
        params: { status: "confirmed" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_confirmed
    end

    it "host can reject a pending member" do
      patch "/api/v1/events/#{event.id}/members/#{member.id}",
        params: { status: "rejected" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_rejected
    end

    it "returns error for invalid transition" do
      member.confirm!
      patch "/api/v1/events/#{event.id}/members/#{member.id}",
        params: { status: "rejected" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "host can approve leave request (leave_requested → cancelled)" do
      member.confirm!
      member.request_leave!

      patch "/api/v1/events/#{event.id}/members/#{member.id}",
        params: { status: "cancelled" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_cancelled
    end

    it "syncs event status to full after confirming enough members" do
      small_script = create(:script, male_slots: 1, female_slots: 1, any_slots: 0)
      small_event = create(:event, script: small_script, host: host)
      create(:event_member, :confirmed, event: small_event, user: create(:user, :male))
      pending_m = create(:event_member, event: small_event, user: applicant)

      patch "/api/v1/events/#{small_event.id}/members/#{pending_m.id}",
        params: { status: "confirmed" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(small_event.reload).to be_full
    end
  end
end
