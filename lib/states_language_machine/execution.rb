# frozen_string_literal: true

require 'securerandom'

module StatesLanguageMachine
  class Execution
    # @return [String, nil] the current state name
    attr_accessor :current_state
    # @return [Hash] the current output data
    attr_accessor :output
    # @return [Symbol] the execution status (:running, :succeeded, :failed)
    attr_accessor :status
    # @return [String, nil] the error type if execution failed
    attr_accessor :error
    # @return [String, nil] the cause of failure if execution failed
    attr_accessor :cause
    # @return [Array<Hash>] the execution history
    attr_accessor :history
    # @return [Logger, nil] the logger for execution
    attr_accessor :logger
    # @return [Hash] the execution context
    attr_accessor :context
    # @return [Time, nil] the execution end time
    attr_accessor :end_time

    # @return [StateMachine] the state machine being executed
    attr_reader :state_machine
    # @return [Hash] the original input data
    attr_reader :input
    # @return [String] the execution name
    attr_reader :name
    # @return [Time] the execution start time
    attr_reader :start_time

    # @param state_machine [StateMachine] the state machine to execute
    # @param input [Hash] the input data for the execution
    # @param name [String, nil] the name of the execution
    # @param context [Hash] additional context for the execution
    def initialize(state_machine, input = {}, name = nil, context = {})
      @state_machine = state_machine
      @input = input.dup
      @name = name || "execution-#{Time.now.to_i}-#{SecureRandom.hex(4)}"
      @current_state = state_machine.start_state
      @output = input.dup
      @status = :running
      @history = []
      @logger = context[:logger]
      @context = context
      @start_time = Time.now
      @end_time = nil
    end

    # Run the entire execution to completion
    # @return [Execution] self
    def run_all
      while @status == :running && @current_state
        run_next
      end
      self
    end

    # Run the next state in the execution
    # @return [Execution] self
    def run_next
      return self unless @status == :running && @current_state

      state = @state_machine.get_state(@current_state)

      begin
        logger&.info("Executing state: #{@current_state}")

        # Execute the current state
        @output = state.execute(self, @output)

        # Check if the state set the execution to failed
        if @status == :failed
          logger&.info("Execution failed in state: #{@current_state}")
          @end_time ||= Time.now
          return self
        end

        # Determine next state - for choice states, we need to pass the output
        next_state = state.next_state_name(@output)

        logger&.info("State #{@current_state} completed. Next state: #{next_state}")

        if state.end_state?
          @status = :succeeded unless @status == :failed
          @current_state = nil
          @end_time = Time.now
          logger&.info("Execution completed successfully")
        elsif next_state
          @current_state = next_state
          logger&.info("Moving to next state: #{next_state}")
        else
          @status = :failed
          @error = "NoNextState"
          @cause = "State '#{@current_state}' has no next state and is not an end state"
          @end_time = Time.now
          logger&.error("Execution failed: #{@cause}")
        end

      rescue => e
        @status = :failed
        @error = e.is_a?(ExecutionError) ? e.cause : "ExecutionError"
        @cause = e.message
        @end_time = Time.now
        logger&.error("Execution failed in state #{@current_state}: #{e.message}")
        logger&.error(e.backtrace.join("\n")) if logger
      end

      self
    end

    # Update the execution output
    # @param new_output [Hash] the new output data
    def update_output(new_output)
      @output = new_output
    end

    # Add an entry to the execution history
    # @param state_name [String] the name of the state that was executed
    # @param output [Hash] the output from the state execution
    def add_history_entry(state_name, output)
      @history << {
        state_name: state_name,
        input: @output, # Current input before execution
        output: output,
        timestamp: Time.now
      }
    end

    # @return [Boolean] whether the execution succeeded
    def succeeded?
      @status == :succeeded
    end

    # @return [Boolean] whether the execution failed
    def failed?
      @status == :failed
    end

    # @return [Boolean] whether the execution is still running
    def running?
      @status == :running
    end

    # @return [Float] the total execution time in seconds
    def execution_time
      return @end_time - @start_time if @end_time
      Time.now - @start_time
    end

    # @return [Hash] the execution details as a Hash
    def to_h
      {
        name: @name,
        status: @status,
        current_state: @current_state,
        input: @input,
        output: @output,
        error: @error,
        cause: @cause,
        start_time: @start_time,
        end_time: @end_time,
        execution_time: execution_time,
        history: @history
      }
    end

    # @return [String] the execution details as JSON
    def to_json
      JSON.pretty_generate(to_h)
    end
  end
end