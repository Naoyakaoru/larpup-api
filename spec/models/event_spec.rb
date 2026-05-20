require "rails_helper"

RSpec.describe Event, type: :model do
  let(:script) { create(:script, male_slots: 1, female_slots: 1, any_slots: 0) }
  let(:script_version) { create(:script_version, script: script) }
  let(:host) { create(:user, :male) }
  let(:event) { create(:event, script_version: script_version, host: host) }

  describe "#sync_status" do
    it "sets status to full when confirmed_count reaches total_slots" do
      male_user = create(:user, :male)
      female_user = create(:user, :female)
      create(:event_member, :confirmed, event: event, user: male_user)
      create(:event_member, :confirmed, event: event, user: female_user)

      event.sync_status
      expect(event.reload).to be_full
    end

    it "sets status back to recruiting when confirmed drops below total_slots" do
      event.update_column(:status, Event.statuses[:full])
      event.sync_status
      expect(event.reload).to be_recruiting
    end

    it "does nothing when cancelled" do
      event.update_column(:status, Event.statuses[:cancelled])
      event.sync_status
      expect(event.reload).to be_cancelled
    end

    it "does nothing when completed" do
      event.update_column(:status, Event.statuses[:completed])
      event.sync_status
      expect(event.reload).to be_completed
    end
  end

  describe "#confirmed_count" do
    it "counts confirmed members plus offline_male and offline_female" do
      user = create(:user, :female)
      create(:event_member, :confirmed, event: event, user: user)
      event.update_columns(offline_male: 1, offline_female: 1)
      event.reload
      # 1 confirmed online + 1 offline_male + 1 offline_female = 3
      expect(event.confirmed_count).to eq(3)
    end

    it "counts offline_male without any online members" do
      event.update_columns(offline_male: 2, offline_female: 0)
      expect(event.confirmed_count).to eq(2)
    end

    it "returns correct count when event_members are preloaded (in-memory path)" do
      user = create(:user, :female)
      create(:event_member, :confirmed, event: event, user: user)
      loaded_event = Event.includes(:event_members).find(event.id)
      expect(loaded_event.event_members).to be_loaded
      expect(loaded_event.confirmed_count).to eq(1)
    end
  end

  describe "#available_slots" do
    it "returns total_slots minus confirmed_count" do
      expect(event.available_slots).to eq(script_version.script.total_slots)
    end
  end

  describe "soft delete" do
    it "is excluded from default scope after soft delete" do
      event.update_column(:deleted_at, Time.current)
      expect(Event.all).not_to include(event)
    end

    it "is visible via unscoped" do
      event.update_column(:deleted_at, Time.current)
      expect(Event.unscoped.all).to include(event)
    end
  end

  describe "#soft_delete! (BE-5)" do
    it "sets deleted_at via update so after_commit audit callback fires" do
      Current.user = host
      event # ensure created before counting
      expect {
        event.soft_delete!
      }.to change { AuditLog.where(auditable: event).count }.by(1)
      log = AuditLog.where(auditable: event).last
      expect(log.action).to eq("updated")
      expect(log.metadata.dig("changes", "deleted_at")).to be_present
      expect(event.reload.deleted_at).not_to be_nil
    ensure
      Current.user = nil
    end

    it "excludes the event from default scope after soft_delete!" do
      event.soft_delete!
      expect(Event.all).not_to include(event)
    end
  end

  describe "#restore! (BE-5)" do
    before { event.update_column(:deleted_at, Time.current) }

    it "clears deleted_at via update so after_commit audit callback fires" do
      Current.user = host
      expect {
        event.restore!
      }.to change { AuditLog.where(auditable: event).count }.by(1)
      log = AuditLog.where(auditable: event).last
      expect(log.action).to eq("updated")
      expect(event.reload.deleted_at).to be_nil
    ensure
      Current.user = nil
    end
  end

  describe "#remaining_slots (BE-1)" do
    let(:script) { create(:script, male_slots: 2, female_slots: 1, any_slots: 1) }
    let(:script_version) { create(:script_version, script: script) }
    let(:event) { create(:event, script_version: script_version, host: host, offline_male: 0, offline_female: 0) }

    it "returns full capacity when no members" do
      slots = event.remaining_slots
      expect(slots).to eq(male: 2, female: 1, any: 1)
    end

    it "decrements male slot when a male member is confirmed" do
      male = create(:user, :male)
      create(:event_member, :confirmed, event: event, user: male)
      slots = event.remaining_slots
      expect(slots[:male]).to eq(1)
      expect(slots[:female]).to eq(1)
    end

    it "decrements female slot when a female member is confirmed" do
      female = create(:user, :female)
      create(:event_member, :confirmed, event: event, user: female)
      slots = event.remaining_slots
      expect(slots[:female]).to eq(0)
    end

    it "accounts for offline_male in slot calculation" do
      event.update_columns(offline_male: 2)
      slots = event.remaining_slots
      expect(slots[:male]).to eq(0)
    end

    it "overflow confirmed goes into any slot" do
      # Fill male_slots (2) and female_slots (1) with online members, next confirmed goes to any
      2.times { create(:event_member, :confirmed, event: event, user: create(:user, :male)) }
      create(:event_member, :confirmed, event: event, user: create(:user, :female))
      slots = event.remaining_slots
      expect(slots[:male]).to eq(0)
      expect(slots[:female]).to eq(0)
      expect(slots[:any]).to eq(1)
    end

    it "handles cross_gender member by treating them as effective opposite gender" do
      # male user with cross_gender=true should fill female slot
      male = create(:user, :male)
      create(:event_member, :confirmed, event: event, user: male, cross_gender: true)
      slots = event.remaining_slots
      expect(slots[:female]).to eq(0)  # female slot consumed
      expect(slots[:male]).to eq(2)    # male slot untouched
    end

    it "returns same result whether event_members are preloaded or not" do
      male = create(:user, :male)
      create(:event_member, :confirmed, event: event, user: male)

      not_loaded = event.remaining_slots
      loaded_event = Event.includes(event_members: :user).find(event.id)
      expect(loaded_event.event_members).to be_loaded
      expect(loaded_event.remaining_slots).to eq(not_loaded)
    end
  end

end
