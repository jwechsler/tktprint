FactoryBot.define do
  factory :print_batch do
    sequence(:batch_id) { |n| "batch_#{Time.current.strftime('%Y%m%d_%H%M%S')}_#{n}" }
    status { 'pending' }
    order_count { 0 }
    printed_count { 0 }
    error_count { 0 }
    error_details { nil }
    ready_at { nil }
    started_at { nil }
    completed_at { nil }

    trait :ready do
      status { 'ready' }
      ready_at { Time.current }
    end

    trait :processing do
      status { 'processing' }
      ready_at { 1.hour.ago }
      started_at { Time.current }
    end

    trait :complete do
      status { 'complete' }
      ready_at { 2.hours.ago }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      order_count { 5 }
      printed_count { 5 }
      error_count { 0 }
    end

    trait :complete_with_error do
      status { 'complete_with_error' }
      ready_at { 2.hours.ago }
      started_at { 1.hour.ago }
      completed_at { Time.current }
      order_count { 5 }
      printed_count { 3 }
      error_count { 2 }
      error_details { 'Some orders failed to print' }
    end

    trait :stale do
      status { 'pending' }
      created_at { 25.hours.ago }
    end
  end
end