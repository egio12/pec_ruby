# frozen_string_literal: true

require 'bundler/setup'
require 'pec_ruby'

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on Module and main
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Add shared context for test data
  config.before(:suite) do
    # Setup any test data or configuration here
  end

  config.after(:suite) do
    # Cleanup after all tests
  end
end