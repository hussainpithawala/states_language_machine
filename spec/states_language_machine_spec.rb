# frozen_string_literal: true

require 'spec_helper'

RSpec.describe StatesLanguageMachine do
  it 'has a version number' do
    expect(StatesLanguageMachine::VERSION).not_to be nil
  end

  describe '.from_yaml' do
    it 'creates a state machine from YAML' do
      yaml = <<~YAML
        StartAt: "TestState"
        States:
          TestState:
            Type: "Pass"
            End: true
      YAML

      state_machine = described_class.from_yaml(yaml)
      expect(state_machine).to be_a(StatesLanguageMachine::StateMachine)
    end
  end
end