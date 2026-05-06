class EventMember < ApplicationRecord
  include AASM

  belongs_to :event
  belongs_to :user

  enum :status, { pending: 0, confirmed: 1, rejected: 2, cancelled: 3, leave_requested: 4 }

  validates :status, presence: true
  validate :event_not_full, on: :create

  aasm column: :status, enum: true do
    state :pending, initial: true
    state :confirmed
    state :rejected
    state :cancelled
    state :leave_requested

    event :confirm do
      transitions from: :pending, to: :confirmed
      after { update_column(:confirmed_at, Time.current) }
    end

    event :reject do
      transitions from: :pending, to: :rejected
      after { update_column(:rejected_at, Time.current) }
    end

    event :request_leave do
      transitions from: :confirmed, to: :leave_requested
      after { update_column(:leave_requested_at, Time.current) }
    end

    event :cancel do
      transitions from: %i[pending leave_requested], to: :cancelled
      after { update_column(:cancelled_at, Time.current) }
    end

    event :reapply do
      transitions from: :cancelled, to: :pending
    end
  end

  def active_member?
    pending? || confirmed? || leave_requested?
  end

  private

  def event_not_full
    errors.add(:event, "is already full") if event&.available_slots&.zero?
  end
end
