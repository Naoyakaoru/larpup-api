FactoryBot.define do
  factory :script do
    sequence(:title) { |n| "Script #{n}" }
    difficulty { 0 }
    male_slots { 2 }
    female_slots { 2 }
    any_slots { 0 }
    genres { [ 0 ] }
    description { "A test script" }
  end
end
