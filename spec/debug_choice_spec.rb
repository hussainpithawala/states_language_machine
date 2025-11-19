# frozen_string_literal: true

require 'spec_helper'
require 'logger'
require 'stringio'

RSpec.describe 'Debug Choice Evaluation' do
  let(:string_io) { StringIO.new }
  let(:logger) { Logger.new(string_io) }
  let(:execution) { instance_double('StatesLanguageMachine::Execution', logger: logger) }

  before do
    logger.level = Logger::DEBUG
  end

  it 'debugs basic numeric comparison' do
    definition = {
      "Type" => "Choice",
      "Choices" => [
        {
          "Variable" => "value",
          "NumericGreaterThan" => 100,
          "Next" => "High"
        }
      ],
      "Default" => "Low"
    }

    choice_state = StatesLanguageMachine::States::Choice.new("TestChoice", definition)
    input = { "value" => 200 }

    allow(execution).to receive(:update_output)
    allow(execution).to receive(:add_history_entry)

    puts "=== Testing basic numeric comparison ==="
    choice_state.execute(execution, input)

    puts "Log output:"
    puts string_io.string

    expect(choice_state.next_state_name).to eq("High")
  end

  it 'debugs JSONPath access' do
    definition = {
      "Type" => "Choice",
      "Choices" => [
        {
          "Variable" => "$.order.total",
          "NumericGreaterThan" => 1000,
          "Next" => "HighValue"
        }
      ],
      "Default" => "NormalValue"
    }

    choice_state = StatesLanguageMachine::States::Choice.new("TestChoice", definition)
    input = {
      "order" => {
        "total" => 1500,
        "id" => "ORD-001"
      }
    }

    allow(execution).to receive(:update_output)
    allow(execution).to receive(:add_history_entry)

    puts "=== Testing JSONPath access ==="
    choice_state.execute(execution, input)

    puts "Log output:"
    puts string_io.string

    expect(choice_state.next_state_name).to eq("HighValue")
  end
end