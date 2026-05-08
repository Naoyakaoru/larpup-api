class Event < ApplicationRecord
  belongs_to :script_version
  belongs_to :host, class_name: "User"
  belongs_to :address, optional: true

  delegate :script, to: :script_version

  has_many :event_members, dependent: :destroy
  has_many :members, through: :event_members, source: :user
  has_many :audit_logs, as: :auditable, dependent: :destroy

  include AASM

  enum :status, { recruiting: 0, full: 1, completed: 2, cancelled: 3 }, default: :recruiting

  aasm column: :status, enum: true do
    state :recruiting, initial: true
    state :full
    state :completed
    state :cancelled

    event :fill do
      transitions from: :recruiting, to: :full
    end

    event :open do
      transitions from: :full, to: :recruiting
    end

    event :complete do
      transitions from: [ :recruiting, :full ], to: :completed
    end

    event :cancel do
      transitions from: [ :recruiting, :full ], to: :cancelled
    end

    event :restore do
      transitions from: :cancelled, to: :recruiting
    end
  end

  default_scope { where(deleted_at: nil) }

  validates :scheduled_at, presence: true
  validates :location, presence: true, unless: :address_id?

  def total_slots
    script_version.script.total_slots
  end

  def confirmed_count
    event_members.confirmed.count + offline_male + offline_female
  end

  def available_slots
    total_slots - confirmed_count
  end

  def sync_status
    return if cancelled? || completed?

    if confirmed_count >= total_slots
      fill! unless full?
    elsif full?
      open!
    end
  end
end
