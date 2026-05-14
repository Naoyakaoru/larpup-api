FactoryBot.define do
  factory :user_consent do
    user
    consent_type { "privacy_policy" }
    consent_version { "2026-05" }
    accepted { true }
    source { "web_signup" }
    ip_address { "127.0.0.1" }
    user_agent { "RSpec Test Agent" }
    accepted_at { Time.current }
  end
end
