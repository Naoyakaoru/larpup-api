class Event < ApplicationRecord
  belongs_to :script
  belongs_to :host, class_name: "User"

  has_many :event_members, dependent: :destroy
  has_many :members, through: :event_members, source: :user

  enum :status, { recruiting: 0, full: 1, completed: 2, cancelled: 3 }, default: :recruiting

  validates :scheduled_at, presence: true
  validates :location, presence: true

  def total_slots
    script.total_slots
  end

  def confirmed_count
    event_members.confirmed.count
  end

  def available_slots
    total_slots - confirmed_count
  end

  def sync_status
    return if cancelled?

    if confirmed_count >= total_slots
      update_column(:status, Event.statuses[:full])
    elsif recruiting? && confirmed_count < total_slots
      # already recruiting, no change needed
    end
  end
end
