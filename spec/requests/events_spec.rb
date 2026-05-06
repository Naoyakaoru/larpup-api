require "rails_helper"

RSpec.describe "Events", type: :request do
  let(:host) { create(:user, :male) }
  let(:other_user) { create(:user, :female) }
  let(:script) { create(:script, male_slots: 2, female_slots: 2) }
  let(:script_version) { create(:script_version, script: script) }
  let!(:event) { create(:event, script_version: script_version, host: host) }

  let(:json) { JSON.parse(response.body) }

  describe "GET /api/v1/events" do
    it "returns all events without auth" do
      get "/api/v1/events"
      expect(response).to have_http_status(:ok)
      expect(json).to be_an(Array)
    end

    it "filters by status" do
      create(:event, :cancelled, script_version: script_version, host: host)
      get "/api/v1/events?status=cancelled"
      expect(json.all? { |e| e["status"] == "cancelled" }).to be true
    end

    it "filters by script_id" do
      other_script = create(:script)
      other_version = create(:script_version, script: other_script)
      other_event = create(:event, script_version: other_version, host: host)
      get "/api/v1/events?script_id=#{other_script.id}"
      expect(json.map { |e| e["id"] }).to contain_exactly(other_event.id)
    end

    it "filters by date (returns events on or after given date)" do
      past_event = create(:event, script_version: script_version, host: host, scheduled_at: 1.week.ago)
      future_event = create(:event, script_version: script_version, host: host, scheduled_at: 1.week.from_now)
      get "/api/v1/events?date=#{Date.today}"
      ids = json.map { |e| e["id"] }
      expect(ids).to include(future_event.id)
      expect(ids).not_to include(past_event.id)
    end
  end

  describe "GET /api/v1/events/:id" do
    it "returns event details" do
      get "/api/v1/events/#{event.id}"
      expect(response).to have_http_status(:ok)
      expect(json["id"]).to eq(event.id)
    end
  end

  describe "POST /api/v1/events" do
    let(:params) do
      {
        script_version_id: script_version.id,
        scheduled_at: 1.week.from_now.iso8601,
        location: "新竹",
        host_in_game: false,
        host_cross_gender: false,
        allow_cross_gender: false,
        offline_male: 0,
        offline_female: 0
      }
    end

    it "creates an event" do
      post "/api/v1/events", params: params.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:created)
      expect(json["location"]).to eq("新竹")
    end

    it "requires authentication" do
      post "/api/v1/events", params: params.to_json,
        headers: { "Content-Type" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
    end

    it "sets status to full when offline members fill all slots on creation" do
      full_script = create(:script, male_slots: 1, female_slots: 0, any_slots: 0)
      full_version = create(:script_version, script: full_script)
      post "/api/v1/events", params: params.merge(script_version_id: full_version.id, offline_male: 1).to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:created)
      expect(json["status"]).to eq("full")
    end

    it "sets status to full when host_in_game fills the last slot on creation" do
      solo_script = create(:script, male_slots: 1, female_slots: 0, any_slots: 0)
      solo_version = create(:script_version, script: solo_script)
      post "/api/v1/events", params: params.merge(script_version_id: solo_version.id, host_in_game: true).to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:created)
      expect(json["status"]).to eq("full")
    end
  end

  describe "PATCH /api/v1/events/:id (update)" do
    it "host can update location and scheduled_at when no members" do
      patch "/api/v1/events/#{event.id}",
        params: { location: "新竹", scheduled_at: 2.weeks.from_now.iso8601 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(json["location"]).to eq("新竹")
    end

    it "host can only update location when members exist" do
      create(:event_member, event: event, user: other_user)
      original_scheduled_at = event.scheduled_at

      patch "/api/v1/events/#{event.id}",
        params: { location: "台中", scheduled_at: 3.weeks.from_now.iso8601 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(json["location"]).to eq("台中")
      expect(event.reload.scheduled_at.to_i).to eq(original_scheduled_at.to_i)
    end

    it "creates an AuditLog when location changes with members" do
      create(:event_member, event: event, user: other_user)

      expect {
        patch "/api/v1/events/#{event.id}",
          params: { location: "高雄" }.to_json,
          headers: { "Content-Type" => "application/json" }.merge(auth_header(host))
      }.to change { AuditLog.count }.by(1)

      expect(AuditLog.last.action).to eq("location_changed")
    end

    it "forbids non-host" do
      patch "/api/v1/events/#{event.id}",
        params: { location: "x" }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:forbidden)
    end

    it "syncs status to full when offline count fills all slots on update" do
      small_script = create(:script, male_slots: 1, female_slots: 1, any_slots: 0)
      small_version = create(:script_version, script: small_script)
      small_event = create(:event, script_version: small_version, host: host)

      patch "/api/v1/events/#{small_event.id}",
        params: { offline_male: 1, offline_female: 1 }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("full")
    end
  end

  describe "PATCH /api/v1/events/:id/cancel" do
    it "cancels the event as host" do
      patch "/api/v1/events/#{event.id}/cancel",
        headers: auth_header(host)

      expect(response).to have_http_status(:ok)
      expect(json["status"]).to eq("cancelled")
    end

    it "returns error if already cancelled" do
      event.update_column(:status, Event.statuses[:cancelled])
      patch "/api/v1/events/#{event.id}/cancel", headers: auth_header(host)

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "forbids non-host" do
      patch "/api/v1/events/#{event.id}/cancel", headers: auth_header(other_user)
      expect(response).to have_http_status(:forbidden)
    end
  end

  describe "DELETE /api/v1/events/:id" do
    it "soft deletes event with no members" do
      delete "/api/v1/events/#{event.id}", headers: auth_header(host)

      expect(response).to have_http_status(:ok)
      expect(Event.find_by(id: event.id)).to be_nil
    end

    it "returns error when event has members" do
      create(:event_member, event: event, user: other_user)
      delete "/api/v1/events/#{event.id}", headers: auth_header(host)

      expect(response).to have_http_status(:unprocessable_entity)
    end
  end

  describe "POST /api/v1/events/:id/join" do
    it "allows user to join" do
      post "/api/v1/events/#{event.id}/join",
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:created)
    end

    it "blocks host from joining own event" do
      post "/api/v1/events/#{event.id}/join",
        headers: { "Content-Type" => "application/json" }.merge(auth_header(host))

      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "allows cancelled member to reapply" do
      member = create(:event_member, :cancelled, event: event, user: other_user)
      post "/api/v1/events/#{event.id}/join",
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:created)
      expect(member.reload).to be_pending
    end

    it "blocks rejected member from rejoining" do
      create(:event_member, :rejected, event: event, user: other_user)
      post "/api/v1/events/#{event.id}/join",
        headers: { "Content-Type" => "application/json" }.merge(auth_header(other_user))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to include("拒絕")
    end
  end

  describe "POST /api/v1/events/:id/join – cross_gender and offline slots" do
    let(:cross_gender_event) { create(:event, script_version: script_version, host: host, allow_cross_gender: true) }

    it "male user with cross_gender fills female slot" do
      male_user = create(:user, :male)
      # 女槽剩 2，讓 male 反串去填
      post "/api/v1/events/#{cross_gender_event.id}/join",
        params: { cross_gender: true }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(male_user))

      expect(response).to have_http_status(:created)
      expect(cross_gender_event.event_members.find_by(user: male_user).cross_gender).to be true
    end

    it "cross_gender is ignored when event does not allow it" do
      male_user = create(:user, :male)
      post "/api/v1/events/#{event.id}/join",
        params: { cross_gender: true }.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(male_user))

      expect(response).to have_http_status(:created)
      expect(event.event_members.find_by(user: male_user).cross_gender).to be false
    end

    it "blocks join when all gender-matching slots are taken by offline members" do
      # Script has male_slots: 2, female_slots: 2
      # Fill all male slots with offline members
      event.update_columns(offline_male: 2)
      male_user = create(:user, :male)

      post "/api/v1/events/#{event.id}/join",
        params: {}.to_json,
        headers: { "Content-Type" => "application/json" }.merge(auth_header(male_user))

      expect(response).to have_http_status(:unprocessable_entity)
      expect(json["error"]).to include("空位")
    end

    it "event becomes full when offline members fill all slots" do
      # 2 male + 2 female offline = total 4 = full
      event.update_columns(offline_male: 2, offline_female: 2)
      event.sync_status

      expect(event.reload).to be_full
    end
  end

  describe "DELETE /api/v1/events/:id/leave" do
    it "cancels a pending member" do
      member = create(:event_member, event: event, user: other_user)
      delete "/api/v1/events/#{event.id}/leave", headers: auth_header(other_user)

      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_cancelled
    end

    it "requests leave for a confirmed member" do
      member = create(:event_member, :confirmed, event: event, user: other_user)
      delete "/api/v1/events/#{event.id}/leave", headers: auth_header(other_user)

      expect(response).to have_http_status(:ok)
      expect(member.reload).to be_leave_requested
    end
  end
end
