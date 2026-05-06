ENV["RAILS_ENV"] ||= "test"
ENV["SECRET_KEY_BASE"] ||= "test_secret_key_base_for_minitest_only"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    # Run tests in parallel with specified workers
    parallelize(workers: :number_of_processors)

    # Setup all fixtures in test/fixtures/*.yml for all tests in alphabetical order.
    fixtures :all

    def auth_header(user)
      token = JwtAuthenticatable.encode(user_id: user.id)
      { "Authorization" => "Bearer #{token}" }
    end
  end
end
