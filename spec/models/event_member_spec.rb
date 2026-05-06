require "rails_helper"

RSpec.describe EventMember, type: :model do
  let(:script) { create(:script, male_slots: 2, female_slots: 2) }
  let(:host) { create(:user, :male) }
  let(:event) { create(:event, script: script, host: host) }
  let(:member_user) { create(:user, :female) }

  describe "AASM transitions" do
    subject(:member) { create(:event_member, event: event, user: member_user) }

    it "starts as pending" do
      expect(member).to be_pending
    end

    it "can be confirmed from pending" do
      expect { member.confirm! }.to change { member.status }.from("pending").to("confirmed")
    end

    it "sets confirmed_at on confirm" do
      member.confirm!
      expect(member.confirmed_at).to be_present
    end

    it "can be rejected from pending" do
      expect { member.reject! }.to change { member.status }.from("pending").to("rejected")
    end

    it "sets rejected_at on reject" do
      member.reject!
      expect(member.rejected_at).to be_present
    end

    it "can request leave from confirmed" do
      member.confirm!
      expect { member.request_leave! }.to change { member.status }.from("confirmed").to("leave_requested")
    end

    it "sets leave_requested_at on request_leave" do
      member.confirm!
      member.request_leave!
      expect(member.leave_requested_at).to be_present
    end

    it "can cancel from pending" do
      expect { member.cancel! }.to change { member.status }.from("pending").to("cancelled")
    end

    it "sets cancelled_at on cancel" do
      member.cancel!
      expect(member.cancelled_at).to be_present
    end

    it "can reapply from cancelled" do
      member.cancel!
      expect { member.reapply! }.to change { member.status }.from("cancelled").to("pending")
    end

    it "cannot go from pending to confirmed then rejected" do
      member.confirm!
      expect { member.reject! }.to raise_error(AASM::InvalidTransition)
    end
  end

  describe "#active_member?" do
    it "returns true for pending" do
      m = create(:event_member, event: event, user: member_user, status: :pending)
      expect(m.active_member?).to be true
    end

    it "returns true for confirmed" do
      m = create(:event_member, :confirmed, event: event, user: member_user)
      expect(m.active_member?).to be true
    end

    it "returns false for rejected" do
      m = create(:event_member, :rejected, event: event, user: member_user)
      expect(m.active_member?).to be false
    end

    it "returns false for cancelled" do
      m = create(:event_member, :cancelled, event: event, user: member_user)
      expect(m.active_member?).to be false
    end
  end
end
