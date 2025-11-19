# frozen_string_literal: true

require 'yaml'
require 'json'

module StatesLanguageMachine
  class StateMachine
    # @return [Hash] the raw definition of the state machine
    attr_reader :definition
    # @return [Hash<String, States::Base>] mapping of state names to state objects
    attr_reader :states
    # @return [String] the name of the starting state
    attr_reader :start_state
    # @return [Integer, nil] the timeout in seconds for the entire state machine
    attr_reader :timeout_seconds
    # @return [String, nil] the comment describing the state machine
    attr_reader :comment

    # @param definition [String, Hash] the state machine definition
    # @param format [Symbol] the format of the definition (:yaml, :json, :hash)
    def initialize(definition, format: :yaml)
      @definition = parse_definition(definition, format)
      validate_definition!
      build_states
    end

    # Start a new execution of this state machine
    # @param input [Hash] the input data for the execution
    # @param execution_name [String, nil] the name of the execution
    # @param context [Hash] additional context for the execution
    # @return [Execution] the execution object
    def start_execution(input = {}, execution_name = nil, context = {})
      Execution.new(self, input, execution_name, context)
    end

    # Get a state by name
    # @param state_name [String] the name of the state to retrieve
    # @return [States::Base] the state object
    # @raise [StateNotFoundError] if the state is not found
    def get_state(state_name)
      @states[state_name] || raise(StateNotFoundError, "State '#{state_name}' not found")
    end

    # @return [Array<String>] the names of all states in the machine
    def state_names
      @states.keys
    end

    # @return [Hash] the state machine definition as a Hash
    def to_h
      @definition.dup
    end

    # @return [String] the state machine definition as JSON
    def to_json
      JSON.pretty_generate(@definition)
    end

    # @return [String] the state machine definition as YAML
    def to_yaml
      YAML.dump(@definition)
    end

    private

    # @param definition [String, Hash] the definition to parse
    # @param format [Symbol] the format of the definition
    # @return [Hash] the parsed definition
    def parse_definition(definition, format)
      case format
      when :yaml
        YAML.safe_load(definition, permitted_classes: [Symbol], aliases: true)
      when :json
        JSON.parse(definition)
      when :hash
        definition
      else
        raise DefinitionError, "Unsupported format: #{format}"
      end
    end

    # Validate the state machine definition
    # @raise [DefinitionError] if the definition is invalid
    def validate_definition!
      raise DefinitionError, "Definition must be a Hash" unless @definition.is_a?(Hash)
      raise DefinitionError, "Missing 'States' field" unless @definition["States"]
      raise DefinitionError, "Missing 'StartAt' field" unless @definition["StartAt"]

      @start_state = @definition["StartAt"]
      @timeout_seconds = @definition["TimeoutSeconds"]
      @comment = @definition["Comment"]

      unless @definition["States"].key?(@start_state)
        raise DefinitionError, "Start state '#{@start_state}' not found in States"
      end
    end

    # Build state objects from the definition
    def build_states
      @states = {}

      @definition["States"].each do |name, state_def|
        @states[name] = create_state(name, state_def)
      end
    end

    # Create a state object from its definition
    # @param name [String] the name of the state
    # @param state_def [Hash] the state definition
    # @return [States::Base] the created state object
    # @raise [DefinitionError] if the state type is unknown
    # Create a state object from its definition
    # @param name [String] the name of the state
    # @param state_def [Hash] the state definition
    # @return [States::Base] the created state object
    # @raise [DefinitionError] if the state type is unknown
    def create_state(name, state_def)
      type = state_def["Type"]

      case type
      when "Task"
        States::Task.new(name, state_def)
      when "Choice"
        States::Choice.new(name, state_def)
      when "Wait"
        States::Wait.new(name, state_def)
      when "Parallel"
        States::Parallel.new(name, state_def)
      when "Pass"
        States::Pass.new(name, state_def)
      when "Succeed"
        States::Succeed.new(name, state_def)
      when "Fail"
        States::Fail.new(name, state_def)
      else
        raise DefinitionError, "Unknown state type: #{type}"
      end
    end
  end
end