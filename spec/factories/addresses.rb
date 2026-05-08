FactoryBot.define do
  factory :address do
    sequence(:name) { |n| "Venue #{n}" }
    address { "123 Test St" }
    map_url { nil }
    region { "taipei_city" }
    deleted_at { nil }
  end
end
