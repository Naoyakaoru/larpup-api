class Event < ApplicationRecord
  belongs_to :script_version
  belongs_to :host, class_name: "User"
  belongs_to :address, optional: true

  delegate :script, to: :script_version

  has_many :event_members, dependent: :destroy
  has_many :members, through: :event_members, source: :user
  include Auditable
  audit_fields :status, :location, :address_id, :scheduled_at, :offline_male, :offline_female, :deleted_at

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

  # BE-4: walk in-memory when already preloaded (avoids N+1 on show/index),
  #        fall back to SQL scope otherwise (keeps correctness in model specs and background jobs).
  def confirmed_count
    if event_members.loaded?
      event_members.count(&:confirmed?) + offline_male + offline_female
    else
      event_members.confirmed.count + offline_male + offline_female
    end
  end

  def available_slots
    total_slots - confirmed_count
  end

  # BE-5: use update() so that after_commit callbacks (audit log, sync_status) fire normally
  def soft_delete!
    update(deleted_at: Time.current)
  end

  def restore!
    update(deleted_at: nil)
  end

  # BE-1: shared slot calculation; caller should preload event_members: :user for best performance.
  #        If not preloaded, falls back to a DB query here (correct but not N+1-free).
  def remaining_slots
    script = script_version.script
    male_filled   = offline_male
    female_filled = offline_female
    any_filled    = 0

    members = event_members.loaded? ? event_members : event_members.includes(:user)
    members.select(&:confirmed?).each do |m|
      user_gender = m.user&.gender
      eg = m.cross_gender ? (user_gender == "male" ? "female" : "male") : user_gender
      if eg == "male" && male_filled < script.male_slots
        male_filled += 1
      elsif eg == "female" && female_filled < script.female_slots
        female_filled += 1
      else
        any_filled += 1
      end
    end

    {
      male:   [ script.male_slots   - male_filled,   0 ].max,
      female: [ script.female_slots - female_filled, 0 ].max,
      any:    [ script.any_slots    - any_filled,    0 ].max,
    }
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
