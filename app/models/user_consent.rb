class UserConsent < ApplicationRecord
  CONSENT_TYPES = %w[privacy_policy terms_of_service marketing cookies ai_features other].freeze

  belongs_to :user

  validates :consent_type,    presence: true, inclusion: { in: CONSENT_TYPES }
  validates :consent_version, presence: true, uniqueness: { scope: [:user_id, :consent_type], message: "has already been accepted" }
  validates :accepted,        inclusion: { in: [ true, false ] }

  # Immutability: consent records must never be modified after creation
  before_update { raise ActiveRecord::ReadOnlyRecord, "UserConsent records are immutable" }
  before_destroy { raise ActiveRecord::ReadOnlyRecord, "UserConsent records are immutable" }
end
