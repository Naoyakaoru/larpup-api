FactoryBot.define do
  factory :event do
    association :script
    association :host, factory: :user
    scheduled_at { 1.week.from_now }
    location { "台北" }
    status { :recruiting }
    allow_cross_gender { false }
    offline_male { 0 }
    offline_female { 0 }

    trait :full do
      status { :full }
    end

    trait :cancelled do
      status { :cancelled }
    end

    trait :completed do
      status { :completed }
    end
  end
end
