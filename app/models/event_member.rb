class EventMember < ApplicationRecord
  belongs_to :event
  belongs_to :user

  enum :status, { pending: 0, confirmed: 1, rejected: 2, cancelled: 3, leave_requested: 4 }

  validates :status, presence: true
  validate :not_host
  validate :event_not_full, on: :create

  private

  def not_host
    errors.add(:user, "cannot join their own event") if event&.host_id == user_id
  end

  def event_not_full
    errors.add(:event, "is already full") if event&.available_slots&.zero?
  end
end
