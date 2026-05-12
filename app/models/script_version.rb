class ScriptVersion < ApplicationRecord
  include Auditable
  audit_fields :price, :available, :duration_override, :version_name

  default_scope { where(deleted_at: nil) }

  belongs_to :script
  belongs_to :store, optional: true

  has_many :events, dependent: :restrict_with_error
  has_many :script_version_addresses, dependent: :destroy
  has_many :addresses, through: :script_version_addresses

  store_accessor :extras, :npc_count, :gm_count, :has_food, :has_costume_change

  validates :available, inclusion: { in: [ true, false ] }

  def effective_duration
    (duration_override || script.duration)&.to_f
  end

  def effective_price
    price&.to_f
  end

  def base?
    store_id.nil?
  end
end
