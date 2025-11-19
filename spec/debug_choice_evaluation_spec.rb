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

  describe 'simple numeric comparison' do
    it 'tests basic negative number comparison' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "total",
            "NumericLessThan" => 0,
            "Next" => "Negative"
          }
        ],
        "Default" => "NonNegative"
      }

      choice_state = StatesLanguageMachine::States::Choice.new("CheckValue", definition)
      input = { "total" => -50.00 }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== SIMPLE NEGATIVE NUMBER TEST ==="
      choice_state.execute(execution, input)

      puts "Next state name: #{choice_state.next_state_name}"
      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("Negative")
    end

    it 'tests positive number comparison' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "total",
            "NumericGreaterThan" => 100,
            "Next" => "High"
          }
        ],
        "Default" => "Low"
      }

      choice_state = StatesLanguageMachine::States::Choice.new("CheckValue", definition)
      input = { "total" => 200 }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== SIMPLE POSITIVE NUMBER TEST ==="
      choice_state.execute(execution, input)

      puts "Next state name: #{choice_state.next_state_name}"
      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("High")
    end
  end

  describe 'JSONPath extraction' do
    it 'tests JSONPath with negative order total' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "$.order.total",
            "NumericLessThan" => 0,
            "Next" => "InvalidOrder"
          }
        ],
        "Default" => "ValidOrder"
      }

      choice_state = StatesLanguageMachine::States::Choice.new("CheckOrderValue", definition)
      input = {
        "order" => {
          "id" => "ORD-004",
          "total" => -50.00
        }
      }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== JSONPATH NEGATIVE ORDER TEST ==="
      choice_state.execute(execution, input)

      puts "Next state name: #{choice_state.next_state_name}"
      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("InvalidOrder")
    end

    it 'tests alternative JSONPath formats' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "order.total",  # Without $ prefix
            "NumericLessThan" => 0,
            "Next" => "Negative"
          }
        ],
        "Default" => "NonNegative"
      }

      choice_state = StatesLanguageMachine::States::Choice.new("CheckValue", definition)
      input = {
        "order" => {
          "total" => -50.00
        }
      }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== ALTERNATIVE JSONPATH TEST ==="
      choice_state.execute(execution, input)

      puts "Next state name: #{choice_state.next_state_name}"
      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("Negative")
    end
  end

  describe 'full workflow test' do
    it 'tests the complete choice evaluation with multiple conditions' do
      yaml_content = <<~YAML
        StartAt: "CheckOrderValue"
        States:
          CheckOrderValue:
            Type: "Choice"
            Choices:
              - Variable: "$.order.total"
                NumericGreaterThanEquals: 1000
                Next: "HighValueProcessing"
              - Variable: "$.order.total"
                NumericGreaterThanEquals: 100
                Next: "MediumValueProcessing"
              - Variable: "$.order.total"
                NumericLessThan: 0
                Next: "InvalidOrder"
            Default: "NormalProcessing"
          
          HighValueProcessing:
            Type: "Pass"
            End: true
          
          MediumValueProcessing:
            Type: "Pass"
            End: true
          
          NormalProcessing:
            Type: "Pass"
            End: true
          
          InvalidOrder:
            Type: "Fail"
            Cause: "Order total cannot be negative"
            Error: "InvalidOrderError"
      YAML

      input = {
        "order" => {
          "id" => "ORD-004",
          "total" => -50.00
        }
      }

      state_machine = StatesLanguageMachine.from_yaml(yaml_content)
      execution = state_machine.start_execution(input, "debug-workflow-test", { logger: logger })

      puts "=== FULL WORKFLOW TEST ==="
      execution.run_all

      puts "Execution result:"
      puts "Status: #{execution.status}"
      puts "Current State: #{execution.current_state}"
      puts "Error: #{execution.error}"
      puts "Cause: #{execution.cause}"
      puts "History: #{execution.history.map { |h| h[:state_name] }.join(' -> ')}"

      puts "Log output:"
      puts string_io.string

      expect(execution.failed?).to be true
      expect(execution.error).to eq("InvalidOrderError")
    end
  end
end