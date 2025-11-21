# frozen_string_literal: true

require 'timeout'
require 'securerandom'
require 'jsonpath'

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
      # @return [String, nil] the credentials ARN for the task
      attr_reader :credentials
      # @return [String, nil] the comment for the state
      attr_reader :comment

      # Intrinsic functions supported by AWS Step Functions
      INTRINSIC_FUNCTIONS = %w[
        States.Format States.StringToJson States.JsonToString
        States.Array States.ArrayPartition States.ArrayContains
        States.ArrayRange States.ArrayGetItem States.ArrayLength
        States.ArrayUnique States.Base64Encode States.Base64Decode
        States.Hash States.JsonMerge States.MathRandom
        States.MathAdd States.StringSplit States.UUID
      ].freeze

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super
        @resource = definition["Resource"]
        @timeout_seconds = definition["TimeoutSeconds"]
        @heartbeat_seconds = definition["HeartbeatSeconds"]
        @parameters = definition["Parameters"] || {}
        @result_path = definition["ResultPath"]
        @result_selector = definition["ResultSelector"]
        @input_path = definition["InputPath"]
        @output_path = definition["OutputPath"]
        @credentials = definition["Credentials"]
        @comment = definition["Comment"]
        @retry = definition["Retry"] || []
        @catch = definition["Catch"] || []

        # Initialize retry and catch objects
        @retry_objects = @retry.map { |r| RetryPolicy.new(r) }
        @catch_objects = @catch.map { |c| CatchPolicy.new(c) }

        validate!
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing task state: #{@name}")
        execution.context[:current_state] = @name
        execution.context[:state_entered_time] = Time.now

        begin
          if @timeout_seconds || @heartbeat_seconds
            execute_with_timeout(execution, input)
          else
            execute_without_timeout(execution, input)
          end
        rescue => error
          handle_execution_error(execution, error, input)
        end
      end

      # Check if this task supports retry for a specific error
      # @param error [Exception] the error to check
      # @param attempt [Integer] the current attempt number
      # @return [RetryPolicy, nil] the retry policy if applicable
      def retry_policy_for(error, attempt)
        @retry_objects.find do |retry_policy|
          retry_policy.matches?(error, attempt)
        end
      end

      # Check if this task has a catch handler for a specific error
      # @param error [Exception] the error to check
      #
      # @return [CatchPolicy, nil] the catch policy if applicable
      def catch_policy_for(error)
        @catch_objects.find do |catch_policy|
          catch_policy.matches?(error)
        end
      end

      private

      # Execute task with timeout and heartbeat support
      def execute_with_timeout(execution, input)
        timeout = @timeout_seconds || 999999 # Very high default timeout

        Timeout.timeout(timeout) do
          if @heartbeat_seconds
            execute_with_heartbeat(execution, input)
          else
            execute_task_logic(execution, input)
          end
        end
      rescue Timeout::Error
        execution.logger&.error("Task '#{@name}' timed out after #{timeout} seconds")
        raise TaskTimeoutError.new("Task timed out after #{timeout} seconds")
      end

      # Execute task with heartbeat monitoring
      def execute_with_heartbeat(execution, input)
        heartbeat_thread = start_heartbeat_monitor(execution)
        result = execute_task_logic(execution, input)
        heartbeat_thread&.kill
        result
      rescue => error
        heartbeat_thread&.kill
        raise error
      end

      # Start heartbeat monitoring thread
      def start_heartbeat_monitor(execution)
        return unless @heartbeat_seconds

        Thread.new do
          loop do
            sleep @heartbeat_seconds
            execution.logger&.debug("Heartbeat from task: #{@name}")
            # In a real implementation, you might send actual heartbeat notifications
          end
        end
      end

      # Execute task without timeout constraints
      def execute_without_timeout(execution, input)
        execute_task_logic(execution, input)
      end

      # Main task execution logic
      def execute_task_logic(execution, input)
        # Apply input path
        processed_input = apply_input_path(input, @input_path)

        # Apply parameters with intrinsic function support
        final_input = apply_parameters(processed_input, execution.context)

        # Execute the actual task
        execution.logger&.debug("Invoking resource: #{@resource}")
        result = execute_task(execution, final_input)

        # Apply result selector
        selected_result = apply_result_selector(result, execution.context)

        # Apply result path
        output = apply_result_path(input, selected_result, @result_path)

        # Apply output path
        final_output = apply_output_path(output, @output_path)

        process_result(execution, final_output)
        final_output
      end

      # Execute the task using the configured executor
      def execute_task(execution, input)
        if execution.context[:task_executor]
          execution.context[:task_executor].call(@resource, input, @credentials)
        else
          simulate_task_execution(input)
        end
      end

      # Simulate task execution for testing/demo
      def simulate_task_execution(input)
        # Simulate some processing time
        sleep(0.1) if ENV['SIMULATE_TASK_DELAY']

        {
          "task_result" => "completed",
          "resource" => @resource,
          "input_received" => input,
          "timestamp" => Time.now.to_i,
          "execution_id" => SecureRandom.uuid,
          "simulated" => true
        }
      end

      # Apply parameters with intrinsic function support
      def apply_parameters(parameters_template, context)
        return parameters_template if parameters_template.empty?

        evaluate_parameters(parameters_template, context)
      end

      # Recursively evaluate parameters including intrinsic functions
      def evaluate_parameters(value, context)
        case value
        when Hash
          value.transform_values { |v| evaluate_parameters(v, context) }
        when Array
          value.map { |v| evaluate_parameters(v, context) }
        when String
          evaluate_intrinsic_functions(value, context)
        else
          value
        end
      end

      # Evaluate intrinsic functions and JSONPath references
      def evaluate_intrinsic_functions(value, context)
        # Handle JSONPath references (starts with $.)
        if value.start_with?('$.')
          return get_value_from_path(context[value[2..-1].to_sym] || {}, value)
        end

        # Handle intrinsic functions
        intrinsic_function = INTRINSIC_FUNCTIONS.find { |func| value.include?(func) }
        return value unless intrinsic_function

        case intrinsic_function
        when 'States.Format'
          evaluate_format_function(value, context)
        when 'States.StringToJson'
          evaluate_string_to_json(value, context)
        when 'States.JsonToString'
          evaluate_json_to_string(value, context)
        when 'States.Array'
          evaluate_array_function(value, context)
        when 'States.MathRandom'
          evaluate_math_random(value, context)
        when 'States.UUID'
          SecureRandom.uuid
        else
          value # Return as-is for unimplemented functions
        end
      end

      # Evaluate States.Format intrinsic function
      def evaluate_format_function(value, context)
        # Extract format string and arguments from the intrinsic function
        match = value.match(/States\.Format\('([^']+)',\s*(.+)\)/)
        return value unless match

        format_string = match[1]
        arguments_json = match[2]

        begin
          arguments = evaluate_parameters(JSON.parse(arguments_json), context)
          format(format_string, *arguments)
        rescue => e
          value # Return original if parsing fails
        end
      end

      # Evaluate States.StringToJson intrinsic function
      def evaluate_string_to_json(value, context)
        match = value.match(/States\.StringToJson\((.+)\)/)
        return value unless match

        string_value = evaluate_parameters(match[1], context)
        JSON.parse(string_value)
      rescue => e
        value
      end

      # Evaluate States.JsonToString intrinsic function
      def evaluate_json_to_string(value, context)
        match = value.match(/States\.JsonToString\((.+)\)/)
        return value unless match

        json_value = evaluate_parameters(match[1], context)
        JSON.generate(json_value)
      rescue => e
        value
      end

      # Evaluate States.Array intrinsic function
      def evaluate_array_function(value, context)
        match = value.match(/States\.Array\((.+)\)/)
        return value unless match

        elements_json = match[1]
        evaluate_parameters(JSON.parse("[#{elements_json}]"), context)
      rescue => e
        value
      end

      # Evaluate States.MathRandom intrinsic function
      def evaluate_math_random(value, context)
        match = value.match(/States\.MathRandom\((\d+),\s*(\d+)\)/)
        return value unless match

        min = match[1].to_i
        max = match[2].to_i
        rand(min..max)
      end

      # Apply result selector to filter and transform task result
      def apply_result_selector(result, context)
        return result unless @result_selector

        evaluate_parameters(@result_selector, context.merge(task_result: result))
      end

      # Handle execution errors with retry and catch logic
      def handle_execution_error(execution, error, input)
        execution.logger&.error("Task execution failed: #{error.class.name} - #{error.message}")

        # Check if we should retry
        retry_policy = retry_policy_for(error, execution.context[:attempt] || 1)
        if retry_policy
          return handle_retry(execution, error, input, retry_policy)
        end

        # Check if we have a catch handler
        catch_policy = catch_policy_for(error)
        if catch_policy
          return handle_catch(execution, error, input, catch_policy)
        end

        # No retry or catch - re-raise the error
        raise error
      end

      # Handle retry logic
      def handle_retry(execution, error, input, retry_policy)
        execution.context[:attempt] = (execution.context[:attempt] || 1) + 1
        execution.logger&.info("Retrying task (attempt #{execution.context[:attempt]})")

        # Apply retry interval
        sleep(retry_policy.interval_seconds) if retry_policy.interval_seconds > 0

        # Retry the execution
        execute(execution, input)
      end

      # Handle catch logic
      def handle_catch(execution, error, input, catch_policy)
        execution.logger&.info("Handling error with catch policy: #{catch_policy.next}")

        # Prepare error result
        error_result = {
          "Error" => error.class.name,
          "Cause" => error.message
        }

        # Apply result path from catch policy or use default
        result_path = catch_policy.result_path || @result_path
        output = apply_result_path(input, error_result, result_path)

        # Transition to next state specified in catch policy
        execution.context[:next_state] = catch_policy.next
        output
      end

      # Validate the task state definition
      def validate!
        super

        raise DefinitionError, "Task state '#{@name}' must have a Resource" unless @resource

        if @timeout_seconds && @timeout_seconds <= 0
          raise DefinitionError, "TimeoutSeconds must be positive"
        end

        if @heartbeat_seconds && @heartbeat_seconds <= 0
          raise DefinitionError, "HeartbeatSeconds must be positive"
        end

        if @heartbeat_seconds && @timeout_seconds && @heartbeat_seconds >= @timeout_seconds
          raise DefinitionError, "HeartbeatSeconds must be less than TimeoutSeconds"
        end

        validate_retry_policies!
        validate_catch_policies!
      end

      def validate_retry_policies!
        @retry_objects.each(&:validate!)
      end

      def validate_catch_policies!
        @catch_objects.each(&:validate!)
      end

      # Helper method to get value from JSONPath
      def get_value_from_path(data, path)
        JsonPath.new(path).first(data)
      rescue
        nil
      end

      # Helper method to set value at JSONPath
      def set_value_at_path(data, path, value)
        # Simple implementation - for production use a proper JSONPath setter
        if path == "$"
          value
        else
          deep_merge(data, create_nested_hash(path.gsub('$.', '').split('.'), value))
        end
      end

      def create_nested_hash(keys, value)
        return value if keys.empty?
        { keys.first => create_nested_hash(keys[1..-1], value) }
      end

      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end
    end

    # Retry policy class
    class RetryPolicy
      attr_reader :error_equals, :interval_seconds, :max_attempts, :backoff_rate

      def initialize(definition)
        @error_equals = Array(definition["ErrorEquals"])
        @interval_seconds = definition["IntervalSeconds"] || 1
        @max_attempts = definition["MaxAttempts"] || 3
        @backoff_rate = definition["BackoffRate"] || 2.0
        @max_delay = definition["MaxDelay"] || 3600 # 1 hour default
      end

      def matches?(error, attempt)
        return false if attempt >= @max_attempts

        @error_equals.any? do |error_match|
          case error_match
          when "States.ALL"
            true
          when "States.Timeout"
            error.is_a?(TaskTimeoutError)
          when "States.TaskFailed"
            error.is_a?(StandardError) && !error.is_a?(TaskTimeoutError)
          when "States.Permissions"
            error.is_a?(SecurityError) || error.message.include?("permission")
          else
            error.class.name == error_match || error.message.include?(error_match)
          end
        end
      end

      def validate!
        if @error_equals.empty?
          raise DefinitionError, "Retry policy must specify ErrorEquals"
        end

        if @interval_seconds < 0
          raise DefinitionError, "IntervalSeconds must be non-negative"
        end

        if @max_attempts < 0
          raise DefinitionError, "MaxAttempts must be non-negative"
        end
      end
    end

    # Catch policy class
    class CatchPolicy
      attr_reader :error_equals, :next, :result_path

      def initialize(definition)
        @error_equals = Array(definition["ErrorEquals"])
        @next = definition["Next"]
        @result_path = definition["ResultPath"]
      end

      def matches?(error)
        @error_equals.any? do |error_match|
          case error_match
          when "States.ALL"
            true
          when "States.Timeout"
            error.is_a?(TaskTimeoutError)
          when "States.TaskFailed"
            error.is_a?(StandardError) && !error.is_a?(TaskTimeoutError)
          when "States.Permissions"
            error.is_a?(SecurityError) || error.message.include?("permission")
          else
            error.class.name == error_match || error.message.include?(error_match)
          end
        end
      end

      def validate!
        if @error_equals.empty?
          raise DefinitionError, "Catch policy must specify ErrorEquals"
        end

        unless @next
          raise DefinitionError, "Catch policy must specify Next state"
        end
      end
    end

    # Custom error classes
    class TaskTimeoutError < StandardError; end
    class TaskExecutionError < StandardError; end
  end
end