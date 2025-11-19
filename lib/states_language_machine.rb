# frozen_string_literal: true

require_relative "states_language_machine/version"
require_relative "states_language_machine/errors"
require_relative "states_language_machine/state_machine"
require_relative "states_language_machine/state"
require_relative "states_language_machine/execution"

# State implementations
require_relative "states_language_machine/states/base"
require_relative "states_language_machine/states/task"
require_relative "states_language_machine/states/choice"
require_relative "states_language_machine/states/wait"
require_relative "states_language_machine/states/parallel"
require_relative "states_language_machine/states/pass"
require_relative "states_language_machine/states/succeed"
require_relative "states_language_machine/states/fail"

module StatesLanguageMachine
  class << self
    # Create a state machine from a YAML string
    # @param yaml_string [String] the YAML definition of the state machine
    # @return [StateMachine] the parsed state machine
    def from_yaml(yaml_string)
      StateMachine.new(yaml_string)
    end

    # Create a state machine from a YAML file
    # @param file_path [String] the path to the YAML file
    # @return [StateMachine] the parsed state machine
    def from_yaml_file(file_path)
      yaml_content = File.read(file_path)
      StateMachine.new(yaml_content)
    end

    # Create a state machine from a JSON string
    # @param json_string [String] the JSON definition of the state machine
    # @return [StateMachine] the parsed state machine
    def from_json(json_string)
      StateMachine.new(json_string, format: :json)
    end

    # Create a state machine from a Hash
    # @param hash [Hash] the Hash definition of the state machine
    # @return [StateMachine] the parsed state machine
    def from_hash(hash)
      StateMachine.new(hash, format: :hash)
    end
  end
end