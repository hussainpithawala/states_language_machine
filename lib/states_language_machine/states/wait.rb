# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Wait < Base
      # @return [Integer, nil] the number of seconds to wait
      attr_reader :seconds
      # @return [String, nil] the timestamp to wait until
      attr_reader :timestamp
      # @return [String, nil] the path to seconds value in input
      attr_reader :seconds_path
      # @return [String, nil] the path to timestamp value in input
      attr_reader :timestamp_path

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super
        @seconds = definition["Seconds"]
        @timestamp = definition["Timestamp"]
        @timestamp_path = definition["TimestampPath"]
        @seconds_path = definition["SecondsPath"]
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing wait state: #{@name}")

        sleep_time = calculate_wait_time(input)
        execution.logger&.info("Waiting for #{sleep_time} seconds")

        # Simulate waiting (in real implementation, you might want non-blocking)
        sleep(sleep_time) if sleep_time > 0

        process_result(execution, input)
        input
      end

      private

      # Calculate how long to wait based on the wait configuration
      # @param input [Hash] the input data
      # @return [Numeric] the number of seconds to wait
      # @raise [ExecutionError] if the wait configuration is invalid
      def calculate_wait_time(input)
        if @seconds
          @seconds.to_i
        elsif @seconds_path
          get_value_from_path(input, @seconds_path).to_i
        elsif @timestamp
          target_time = Time.parse(@timestamp)
          [target_time - Time.now, 0].max
        elsif @timestamp_path
          timestamp_value = get_value_from_path(input, @timestamp_path)
          target_time = Time.parse(timestamp_value.to_s)
          [target_time - Time.now, 0].max
        else
          0
        end
      rescue => e
        raise ExecutionError.new(@name, "Invalid wait configuration: #{e.message}")
      end

      # Validate the wait state definition
      # @raise [DefinitionError] if the definition is invalid
      def validate!
        super
        wait_methods = [@seconds, @timestamp, @seconds_path, @timestamp_path].compact
        if wait_methods.size != 1
          raise DefinitionError, "Wait state '#{@name}' must have exactly one of: Seconds, Timestamp, SecondsPath, or TimestampPath"
        end
      end
    end
  end
end