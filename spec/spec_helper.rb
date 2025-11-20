# frozen_string_literal: true

require 'bundler/setup'
require 'states_language_machine'
require 'logger'
require 'stringio'

# Configure RSpec
RSpec.configure do |config|
  # Use the documentation formatter for detailed output
  config.formatter = :documentation

  # Use color in STDOUT
  config.color = true

  # Use color not only in STDOUT but also in pagers and files
  config.tty = true

  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = '.rspec_status'

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Add time helpers for wait state testing
  config.around(:each) do |example|
    # Allow time-based tests to run without actual long waits
    if example.metadata[:skip_time_wait]
      allow_any_instance_of(WaitState).to receive(:sleep)
      example.run
    else
      example.run
    end
  end
end

# Load all support files
support_files = Dir[File.join(__dir__, 'support', '**', '*.rb')]
support_files.each { |f| require f }

# Load all spec files
spec_files = Dir[File.join(__dir__, '**', '*_spec.rb')]
spec_files.each { |f| require f }