class ScriptVersion < ApplicationRecord
  belongs_to :script
  belongs_to :store, optional: true

  has_many :events, dependent: :restrict_with_error

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
