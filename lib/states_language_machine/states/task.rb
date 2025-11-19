# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Task < Base
      # @return [String] the resource ARN or URI to invoke
      attr_reader :resource
      # @return [Integer, nil] the timeout in seconds for the task
      attr_reader :timeout_seconds
      # @return [Integer, nil] the heartbeat interval in seconds
      attr_reader :heartbeat_seconds
      # @return [Array<Hash>] the retry configuration
      attr_reader :retry
      # @return [Array<Hash>] the catch configuration
      attr_reader :catch
      # @return [Hash] the parameters to pass to the resource
      attr_reader :parameters
      # @return [String, nil] the result path
      attr_reader :result_path
      # @return [Hash, nil] the result selector
      attr_reader :result_selector
      # @return [String, nil] the input path
      attr_reader :input_path
      # @return [String, nil] the output path
      attr_reader :output_path

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        @resource = definition["Resource"]
        @timeout_seconds = definition["TimeoutSeconds"]
        @heartbeat_seconds = definition["HeartbeatSeconds"]
        @parameters = definition["Parameters"] || {}
        @result_path = definition["ResultPath"]
        @result_selector = definition["ResultSelector"]
        @input_path = definition["InputPath"]
        @output_path = definition["OutputPath"]
        @retry = definition["Retry"] || []
        @catch = definition["Catch"] || []
        super
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing task state: #{@name}")
        
        processed_input = apply_input_path(input, @input_path)
        
        # Apply parameters if specified
        final_input = apply_parameters(processed_input)
        
        result = execute_task(execution, final_input)
        
        # Apply result selector if specified
        selected_result = apply_result_selector(result)
        
        # Apply result path
        output = apply_result_path(input, selected_result, @result_path)
        
        # Apply output path
        final_output = apply_output_path(output, @output_path)
        
        process_result(execution, final_output)
        final_output
      end

      private

      # Execute the task
      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the task
      # @return [Hash] the task result
      def execute_task(execution, input)
        # This is where you would integrate with actual task executors
        # For demonstration, we'll return a simulated result
        execution.context[:task_executor]&.call(@resource, input) || simulate_task_execution(input)
      end

      # Simulate task execution for demonstration
      # @param input [Hash] the input data
      # @return [Hash] the simulated result
      def simulate_task_execution(input)
        {
          "task_result" => "completed",
          "resource" => @resource,
          "input_received" => input,
          "timestamp" => Time.now.to_i,
          "execution_id" => SecureRandom.uuid
        }
      end

      # Apply parameters to input data
      # @param input [Hash] the input data
      # @return [Hash] the input data with parameters applied
      def apply_parameters(input)
        return input if @parameters.empty?
        
        # Simple parameter application - in real implementation, 
        # you'd want to handle JSONPath references
        deep_merge(input, @parameters)
      end

      # Apply result selector to filter task result
      # @param result [Hash] the task result
      # @return [Hash] the filtered result
      def apply_result_selector(result)
        return result unless @result_selector
        
        # Simple selector application
        @result_selector.transform_values do |selector|
          if selector.is_a?(String) && selector.start_with?('$')
            get_value_from_path(result, selector[1..])
          else
            selector
          end
        end
      end

      # Validate the task state definition
      # @raise [DefinitionError] if the definition is invalid
      def validate!
        super
        raise DefinitionError, "Task state '#{@name}' must have a Resource" unless @resource
      end
    end
  end
end