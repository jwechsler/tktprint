FactoryBot.define do
  factory :order do
    sequence(:remote_id) { |n| n }
    first_name { 'John' }
    last_name { 'Doe' }
    title { 'Test Show' }
    venue { 'Theater Wit' }
    theater { 'Theater Wit' }
    performance_date { Date.current }
    performance_time { Time.current }
    performance_code { 'TS001' }
    patron_code { 'PATRON001' }
    credit_1 { 'Director: Jane Smith' }
    credit_2 { 'Producer: Bob Johnson' }
    status { 'Unprinted' }
    print_status { 'unprinted' }
    amount { 25.00 }
    batch_id { nil }
    batch_sequence { nil }
    printed_at { nil }
    print_error { nil }

    trait :printed do
      status { 'Printed' }
      print_status { 'printed' }
      printed_at { Time.current }
    end

    trait :print_error do
      print_status { 'error: printer jam' }
      print_error { 'printer jam' }
    end

    trait :in_batch do
      batch_id { 'test_batch_001' }
      batch_sequence { 1 }
    end

    trait :with_tickets do
      after(:create) do |order|
        create_list(:ticket, 2, order: order)
      end
    end
  end
end