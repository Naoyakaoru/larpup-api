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
      # 1 confirmed online + 1 offline_male + 1 offline_female = 3
      expect(event.confirmed_count).to eq(3)
    end

    it "counts offline_male without any online members" do
      event.update_columns(offline_male: 2, offline_female: 0)
      expect(event.confirmed_count).to eq(2)
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
end
