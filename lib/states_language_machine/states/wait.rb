require 'time'

module StatesLanguageMachine
  module States
    class Wait
      attr_reader :state_type, :seconds, :timestamp, :seconds_path, :timestamp_path, :next_state, :end_state

      def initialize(definition, state_name)
        @state_name = state_name

        # Ensure definition is a Hash and extract values safely
        @state_type = definition.is_a?(Hash) ? definition["Type"] : nil
        @seconds = definition.is_a?(Hash) ? definition["Seconds"] : nil
        @timestamp = definition.is_a?(Hash) ? definition["Timestamp"] : nil
        @seconds_path = definition.is_a?(Hash) ? definition["SecondsPath"] : nil
        @timestamp_path = definition.is_a?(Hash) ? definition["TimestampPath"] : nil
        @next_state = definition.is_a?(Hash) ? definition["Next"] : nil

        # Safely handle End key - check if it exists and is truthy
        if definition.is_a?(Hash)
          @end_state = definition.key?("End") ? !!definition["End"] : false
        else
          @end_state = false
        end

        validate
      end

      def execute(context)
        # Determine how long to wait
        wait_seconds = calculate_wait_seconds(context)

        # Perform the wait
        sleep(wait_seconds) if wait_seconds > 0

        # Return execution result
        ExecutionResult.new(
          next_state: @end_state ? nil : @next_state,
          output: context.execution_input,
          end_execution: @end_state
        )
      end

      private

      def calculate_wait_seconds(context)
        if @seconds
          @seconds.to_i
        elsif @timestamp
          target_time = Time.parse(@timestamp)  # Use :: to specify the class method
          wait_time = target_time - Time.now
          wait_time > 0 ? wait_time : 0
        elsif @seconds_path
          seconds_value = extract_path_value(context.execution_input, @seconds_path)
          validate_seconds_value(seconds_value)
          seconds_value.to_i
        elsif @timestamp_path
          timestamp_value = extract_path_value(context.execution_input, @timestamp_path)
          target_time = Time.parse(timestamp_value)  # Use :: to specify the class method
          wait_time = target_time - Time.now
          wait_time > 0 ? wait_time : 0
        else
          0
        end
      end

      def extract_path_value(input, path)
        # Simple path extraction - you might want to use a JSONPath library
        if path.start_with?("$.")
          key = path[2..-1]
          input[key]
        else
          input[path]
        end
      end

      def validate_seconds_value(seconds)
        return if seconds.is_a?(Integer) && seconds >= 0
        return if seconds.is_a?(String) && seconds.match?(/^\d+$/) && seconds.to_i >= 0

        raise StatesLanguageMachine::Error, "Seconds value must be a positive integer"
      end

      def validate
        raise StatesLanguageMachine::Error, "State definition must be a Hash" unless @state_type

        wait_methods = [@seconds, @timestamp, @seconds_path, @timestamp_path].compact
        raise StatesLanguageMachine::Error, "Wait state must specify one of: Seconds, Timestamp, SecondsPath, or TimestampPath" if wait_methods.empty?

        raise StatesLanguageMachine::Error, "Wait state can only specify one wait method" if wait_methods.size > 1

        validate_seconds_value(@seconds) if @seconds

        if @timestamp
          begin
            ::Time.parse(@timestamp)  # Use :: to specify the class method
          rescue ArgumentError
            raise StatesLanguageMachine::Error, "Invalid timestamp format: #{@timestamp}"
          end
        end

        if @end_state && @next_state
          raise StatesLanguageMachine::Error, "Wait state cannot have both 'End' and 'Next'"
        end

        unless @end_state || @next_state
          raise StatesLanguageMachine::Error, "Wait state must have either 'End' or 'Next'"
        end
      end
    end

    # Simple result class for execution
    class ExecutionResult
      attr_reader :next_state, :output, :end_execution

      def initialize(next_state: nil, output: nil, end_execution: false)
        @next_state = next_state
        @output = output
        @end_execution = end_execution
      end
    end
  end
end