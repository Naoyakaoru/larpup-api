FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    sequence(:nickname) { |n| "User#{n}" }
    password_digest { BCrypt::Password.create("password123") }
    gender { "female" }
    is_admin { false }

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
