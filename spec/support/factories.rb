FactoryGirl.define do
  factory :user do
    email "example.user@test.com"
    password "secret"

    initialize_with { new(SecureRandom.uuid) }
  end

  factory :admin, :class => User do
    email "example.admin@test.com"
    password "admin_secret"

    initialize_with { new(SecureRandom.uuid) }
  end

  factory :other, :class => User do
    email "other.user@test.com"
    password "other_secret"

    initialize_with { new(SecureRandom.uuid) }
  end
end
