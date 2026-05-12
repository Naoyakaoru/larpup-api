class Event < ApplicationRecord
  belongs_to :script_version
  belongs_to :host, class_name: "User"
  belongs_to :address, optional: true

  delegate :script, to: :script_version

  has_many :event_members, dependent: :destroy
  has_many :members, through: :event_members, source: :user
  include Auditable
  audit_fields :status, :location, :address_id, :scheduled_at

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

  private

  def enrich_audit_changes(changes)
    has_location   = changes.key?("location")
    has_address_id = changes.key?("address_id")
    return changes unless has_location || has_address_id

    old_addr_id  = changes.dig("address_id", 0)
    new_addr_id  = changes.dig("address_id", 1)
    old_loc_text = changes.dig("location", 0)
    new_loc_text = changes.dig("location", 1)

    old_display = old_addr_id ? Address.find_by(id: old_addr_id)&.name : old_loc_text
    new_display = new_addr_id ? Address.find_by(id: new_addr_id)&.name : new_loc_text

    rest = changes.except("address_id", "location")
    return rest if old_display == new_display

    rest.merge("location" => [ old_display, new_display ])
  end
end
