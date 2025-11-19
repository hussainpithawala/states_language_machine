# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Succeed < Base
      # @return [String, nil] the input path
      attr_reader :input_path
      # @return [String, nil] the output path
      attr_reader :output_path

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super
        @input_path = definition["InputPath"]
        @output_path = definition["OutputPath"]
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing succeed state: #{@name}")

        processed_input = apply_input_path(input, @input_path)
        final_output = apply_output_path(processed_input, @output_path)

        execution.status = :succeeded
        process_result(execution, final_output)
        final_output
      end

      # Validate the succeed state definition
      def validate!
        # Succeed states don't need Next or End
      end
    end
  end
end