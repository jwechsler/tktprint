FactoryBot.define do
  factory :ticket do
    association :order
    seat { 'A1' }
    ticket_number { 'T001' }
    status { 'active' }

    trait :general_admission do
      seat { nil }
    end

    trait :reserved_seating do
      seat { 'B5' }
    end
  end
end