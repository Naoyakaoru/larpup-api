class ScriptVersion < ApplicationRecord
  belongs_to :script
  belongs_to :store, optional: true

  has_many :events, dependent: :restrict_with_error

  validates :available, inclusion: { in: [ true, false ] }

  def effective_duration
    duration_override || script.duration
  end

  def effective_price
    price
  end

  def base?
    store_id.nil?
  end
end
