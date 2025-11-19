# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Pass < Base
      # @return [Object, nil] the result to pass through
      attr_reader :result
      # @return [String, nil] the result path
      attr_reader :result_path
      # @return [String, nil] the input path
      attr_reader :input_path
      # @return [String, nil] the output path
      attr_reader :output_path

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super
        @result = definition["Result"]
        @result_path = definition["ResultPath"]
        @input_path = definition["InputPath"]
        @output_path = definition["OutputPath"]
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing pass state: #{@name}")

        processed_input = apply_input_path(input, @input_path)

        result = @result || processed_input
        output = apply_result_path(input, result, @result_path)
        final_output = apply_output_path(output, @output_path)

        process_result(execution, final_output)
        final_output
      end
    end
  end
end