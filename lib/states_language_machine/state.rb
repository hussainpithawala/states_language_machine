# frozen_string_literal: true

module StatesLanguageMachine
  # Base state class that provides common functionality for all states
  class State
    # @return [String] the name of the state
    attr_reader :name
    # @return [String] the type of the state
    attr_reader :type
    # @return [String, nil] the next state name
    attr_reader :next_state
    # @return [Boolean] whether this is an end state
    attr_reader :end_state

    # @param name [String] the name of the state
    # @param definition [Hash] the state definition
    def initialize(name, definition)
      @name = name
      @type = definition["Type"]
      @next_state = definition["Next"]
      @end_state = definition.key?("End") && definition["End"]
      @definition = definition
    end

    # Get the next state name (can be overridden by subclasses that need input)
    # @param input [Hash, nil] the input data (optional, for choice states)
    # @return [String, nil] the next state name
    def next_state_name(input = nil)
      return nil if end_state?
      @next_state
    end

    # @return [Boolean] whether this state is an end state
    def end_state?
      @end_state
    end

    # Execute the state (to be implemented by subclasses)
    # @param execution [Execution] the current execution
    # @param input [Hash] the input data
    # @return [Hash] the output data
    # @raise [NotImplementedError] if not implemented by subclass
    def execute(execution, input)
      raise NotImplementedError, "Subclasses must implement execute method"
    end
  end
end