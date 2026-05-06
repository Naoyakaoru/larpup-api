FactoryBot.define do
  factory :store do
    sequence(:name) { |n| "Store #{n}" }
    status { "active" }
    association :owner, factory: :user
  end
end
