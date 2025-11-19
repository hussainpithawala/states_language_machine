# frozen_string_literal: true

module StatesLanguageMachine
  class Error < StandardError; end

  class ExecutionError < Error
    # @return [String] the name of the state where the error occurred
    attr_reader :state_name
    # @return [String] the cause of the error
    attr_reader :cause

    # @param state_name [String] the name of the state where the error occurred
    # @param cause [String] the cause of the error
    def initialize(state_name, cause)
      @state_name = state_name
      @cause = cause
      super("Execution failed in state '#{state_name}': #{cause}")
    end
  end

  class DefinitionError < Error; end
  class StateNotFoundError < Error; end
  class TimeoutError < Error; end
end