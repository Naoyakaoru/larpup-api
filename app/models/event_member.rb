class EventMember < ApplicationRecord
  belongs_to :event
  belongs_to :user

  enum :status, { pending: 0, confirmed: 1, rejected: 2, cancelled: 3, leave_requested: 4 }

  validates :status, presence: true
  validate :event_not_full, on: :create

  private

  def event_not_full
    errors.add(:event, "is already full") if event&.available_slots&.zero?
  end
end
