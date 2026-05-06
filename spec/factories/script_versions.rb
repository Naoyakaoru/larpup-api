FactoryBot.define do
  factory :script_version do
    association :script
    store { nil }
    version_name { nil }
    price { nil }
    available { true }
    duration_override { nil }
  end
end
