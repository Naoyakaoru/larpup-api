FactoryBot.define do
  factory :event_member do
    association :event
    association :user
    status { :pending }
    cross_gender { false }

    trait :confirmed do
      status { :confirmed }
      confirmed_at { Time.current }
    end

    trait :rejected do
      status { :rejected }
      rejected_at { Time.current }
    end

    trait :cancelled do
      status { :cancelled }
      cancelled_at { Time.current }
    end

    trait :leave_requested do
      status { :leave_requested }
      leave_requested_at { Time.current }
    end
  end
end
