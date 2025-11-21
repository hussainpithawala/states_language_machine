# frozen_string_literal: true

require 'bundler/setup'
require 'ruby_slm'
require 'logger'
require 'stringio'

# Mock only what's necessary for testing
module StatesLanguageMachine
  # Mock StateMachine for testing that properly simulates failures
  class TestStateMachine
    def initialize(definition, format: :hash)
      @definition = definition
    end

    def start_execution(input, name, context)
      execution = Object.new

      # Extract the expected output from the branch definition
      output = extract_output_from_definition(@definition)

      # Determine if this branch should fail based on its definition
      should_fail = branch_should_fail?(@definition)

      execution.define_singleton_method(:run_all) { }
      execution.define_singleton_method(:succeeded?) { !should_fail }
      execution.define_singleton_method(:output) { output }
      execution.define_singleton_method(:error) { should_fail ? "Branch execution failed" : nil }
      execution
    end

    private

    def extract_output_from_definition(definition)
      return {} unless definition['States']

      # Find the first state that has a Result
      definition['States'].each do |state_name, state_def|
        if state_def['Result']
          return state_def['Result']
        end
      end

      # Fallback: return empty hash if no Result found
      {}
    end

    def branch_should_fail?(definition)
      return false unless definition['States']

      # Check if any state in this branch is a Fail state
      definition['States'].each do |state_name, state_def|
        if state_def['Type'] == 'Fail'
          return true
        end
      end

      false
    end
  end
end

# Configure RSpec
RSpec.configure do |config|
  config.formatter = :documentation
  config.color = true
  config.tty = true
  config.example_status_persistence_file_path = '.rspec_status'
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end

  # Mock the StateMachine class in parallel tests
  config.before(:each) do
    if described_class == StatesLanguageMachine::States::Parallel
      stub_const('StatesLanguageMachine::StateMachine', StatesLanguageMachine::TestStateMachine)
    end
  end

  config.around(:each) do |example|
    if example.metadata[:skip_time_wait] && defined?(StatesLanguageMachine::States::Wait)
      # allow_any_instance_of(StatesLanguageMachine::States::Wait).to receive(:sleep)
    end
    example.run
  end
end

# Load support files and specs
Dir[File.join(__dir__, 'support', '**', '*.rb')].each { |f| require f }
Dir[File.join(__dir__, '**', '*_spec.rb')].each { |f| require f }