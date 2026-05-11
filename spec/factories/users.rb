FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:nickname) { |n| "User#{n}" }
    sequence(:handle) { |n| "user#{n.to_s.rjust(6, '0')}" }
    password { "password123" }
    gender { "female" }
    is_admin { false }
    show_hosted_events { false }

    trait :male do
      gender { "male" }
    end

    trait :female do
      gender { "female" }
    end

    trait :admin do
      is_admin { true }
    end
  end
end
