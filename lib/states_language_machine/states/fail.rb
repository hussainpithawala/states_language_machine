# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Fail < Base
      # @return [String] the cause of the failure
      attr_reader :cause
      # @return [String] the error type
      attr_reader :error

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        # Don't call super - we need to handle this differently for Fail states
        @name = name
        @type = definition["Type"]
        @cause = definition["Cause"]
        @error = definition["Error"]
        @definition = definition
        @end_state = true  # Fail states are always end states
        @next_state = nil  # Fail states never have next states

        validate!
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing fail state: #{@name}")

        # Set execution status to failed
        execution.status = :failed
        execution.error = @error
        execution.cause = @cause

        process_result(execution, input)

        input
      end

      # Fail states are always end states
      # @return [Boolean] always true for fail states
      def end_state?
        true
      end

      # Fail states don't have next states
      # @return [nil] always nil for fail states
      def next_state_name(input = nil)
        nil
      end

      # Validate the fail state definition
      # @raise [DefinitionError] if the definition is invalid
      def validate!
        raise DefinitionError, "Fail state '#{@name}' must have a Cause" unless @cause
        raise DefinitionError, "Fail state '#{@name}' must have an Error" unless @error
      end
    end
  end
end