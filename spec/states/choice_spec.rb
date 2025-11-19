# frozen_string_literal: true

require 'spec_helper'
require 'logger'
require 'stringio'

RSpec.describe StatesLanguageMachine::States::Choice do
  let(:logger) { Logger.new(StringIO.new) }
  let(:execution) { instance_double('StatesLanguageMachine::Execution', logger: logger) }

  describe '#initialize' do
    it 'initializes with choices and default' do
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

      choice_state = described_class.new("TestChoice", definition)

      expect(choice_state.name).to eq("TestChoice")
      expect(choice_state.type).to eq("Choice")
      expect(choice_state.choices).to eq(definition["Choices"])
      expect(choice_state.default).to eq("Low")
    end

    it 'handles empty choices array' do
      definition = {
        "Type" => "Choice",
        "Choices" => [],
        "Default" => "DefaultState"
      }

      choice_state = described_class.new("TestChoice", definition)
      expect(choice_state.choices).to eq([])
      expect(choice_state.default).to eq("DefaultState")
    end

    it 'validates without raising errors for choice states' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericGreaterThan" => 100,
            "Next" => "High"
          }
        ]
        # No Default specified - should be valid for choice states
      }

      expect { described_class.new("TestChoice", definition) }.not_to raise_error
    end
  end

  describe '#execute' do
    it 'evaluates choices and selects the correct next state' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericGreaterThan" => 100,
            "Next" => "High"
          },
          {
            "Variable" => "value",
            "NumericGreaterThan" => 50,
            "Next" => "Medium"
          }
        ],
        "Default" => "Low"
      }

      choice_state = described_class.new("CheckValue", definition)
      input = { "value" => 200 }

      expect(execution).to receive(:logger).at_least(:once)
      expect(execution).to receive(:update_output)
      expect(execution).to receive(:add_history_entry)

      result = choice_state.execute(execution, input)

      expect(result).to eq(input) # Choice states don't modify input
      expect(choice_state.next_state_name).to eq("High")
    end

    it 'uses default when no choices match' do
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

      choice_state = described_class.new("CheckValue", definition)
      input = { "value" => 50 }

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      result = choice_state.execute(execution, input)

      expect(result).to eq(input)
      expect(choice_state.next_state_name).to eq("Low")
    end
  end

  describe '#next_state_name' do
    it 'returns evaluated next state after execution' do
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

      choice_state = described_class.new("CheckValue", definition)
      input = { "value" => 200 }

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, input)

      expect(choice_state.next_state_name).to eq("High")
    end

    it 'evaluates on the fly when no execution has occurred' do
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

      choice_state = described_class.new("CheckValue", definition)
      input = { "value" => 200 }

      expect(choice_state.next_state_name(input)).to eq("High")
    end

    it 'returns default when no input provided and no execution occurred' do
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

      choice_state = described_class.new("CheckValue", definition)

      expect(choice_state.next_state_name).to eq("Low")
    end
  end

  describe 'numeric comparisons' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericGreaterThan" => 100,
            "Next" => "High"
          },
          {
            "Variable" => "value",
            "NumericGreaterThan" => 50,
            "Next" => "Medium"
          }
        ],
        "Default" => "Low"
      }
    end

    let(:choice_state) { described_class.new("CheckValue", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'handles high values correctly' do
      input = { "value" => 200 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("High")
    end

    it 'handles medium values correctly' do
      input = { "value" => 75 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Medium")
    end

    it 'handles low values correctly' do
      input = { "value" => 25 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Low")
    end

    it 'handles boundary values correctly' do
      input = { "value" => 100 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Medium") # 100 > 50 but not > 100

      input = { "value" => 50 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Low") # 50 is not > 50
    end

    it 'handles string numbers' do
      input = { "value" => "200" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("High")
    end

    it 'handles float numbers' do
      input = { "value" => 75.5 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Medium")
    end

    it 'tests with simple input structure' do
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

      choice_state = described_class.new("CheckValue", definition)
      input = { "total" => -50.00 }

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Negative")
    end
  end

  describe 'string comparisons' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "status",
            "StringEquals" => "approved",
            "Next" => "Process"
          },
          {
            "Variable" => "status",
            "StringEquals" => "pending",
            "Next" => "Wait"
          }
        ],
        "Default" => "Reject"
      }
    end

    let(:choice_state) { described_class.new("CheckStatus", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'matches string equals' do
      input = { "status" => "approved" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Process")
    end

    it 'matches different string' do
      input = { "status" => "pending" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Wait")
    end

    it 'uses default for non-matching string' do
      input = { "status" => "rejected" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Reject")
    end
  end

  describe 'boolean comparisons' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "active",
            "BooleanEquals" => true,
            "Next" => "Process"
          }
        ],
        "Default" => "Skip"
      }
    end

    let(:choice_state) { described_class.new("CheckActive", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'matches true boolean' do
      input = { "active" => true }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Process")
    end

    it 'matches string true' do
      input = { "active" => "true" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Process")
    end

    it 'uses default for false' do
      input = { "active" => false }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Skip")
    end

    it 'uses default for string false' do
      input = { "active" => "false" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Skip")
    end
  end

  describe 'JSONPath variable access' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "$.order.total",
            "NumericGreaterThan" => 1000,
            "Next" => "HighValue"
          },
          {
            "Variable" => "$.order.total",
            "NumericGreaterThan" => 100,
            "Next" => "MediumValue"
          }
        ],
        "Default" => "NormalValue"
      }
    end

    let(:choice_state) { described_class.new("CheckOrder", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'accesses nested values with JSONPath syntax' do
      input = {
        "order" => {
          "total" => 1500,
          "id" => "ORD-001"
        }
      }

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("HighValue")
    end

    it 'handles medium values with nested data' do
      input = {
        "order" => {
          "total" => 500,
          "id" => "ORD-002"
        }
      }

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("MediumValue")
    end

    it 'handles normal values with nested data' do
      input = {
        "order" => {
          "total" => 50,
          "id" => "ORD-003"
        }
      }

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NormalValue")
    end
  end

  describe 'composite conditions' do
    context 'with AND conditions' do
      let(:definition) do
        {
          "Type" => "Choice",
          "Choices" => [
            {
              "And" => [
                {
                  "Variable" => "inventory.available",
                  "BooleanEquals" => true
                },
                {
                  "Variable" => "inventory.quantity",
                  "NumericGreaterThan" => 0
                }
              ],
              "Next" => "Ship"
            }
          ],
          "Default" => "Backorder"
        }
      end

      let(:choice_state) { described_class.new("CheckInventory", definition) }

      before do
        allow(execution).to receive(:logger)
        allow(execution).to receive(:update_output)
        allow(execution).to receive(:add_history_entry)
      end

      it 'matches when all AND conditions are true' do
        input = {
          "inventory" => {
            "available" => true,
            "quantity" => 5
          }
        }

        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Ship")
      end

      it 'does not match when one AND condition is false' do
        input = {
          "inventory" => {
            "available" => true,
            "quantity" => 0
          }
        }

        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Backorder")
      end
    end

    context 'with OR conditions' do
      let(:definition) do
        {
          "Type" => "Choice",
          "Choices" => [
            {
              "Or" => [
                {
                  "Variable" => "priority",
                  "StringEquals" => "high"
                },
                {
                  "Variable" => "urgent",
                  "BooleanEquals" => true
                }
              ],
              "Next" => "Expedite"
            }
          ],
          "Default" => "Normal"
        }
      end

      let(:choice_state) { described_class.new("CheckPriority", definition) }

      before do
        allow(execution).to receive(:logger)
        allow(execution).to receive(:update_output)
        allow(execution).to receive(:add_history_entry)
      end

      it 'matches when first OR condition is true' do
        input = { "priority" => "high", "urgent" => false }
        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Expedite")
      end

      it 'matches when second OR condition is true' do
        input = { "priority" => "low", "urgent" => true }
        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Expedite")
      end

      it 'does not match when no OR conditions are true' do
        input = { "priority" => "low", "urgent" => false }
        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Normal")
      end
    end

    context 'with NOT conditions' do
      let(:definition) do
        {
          "Type" => "Choice",
          "Choices" => [
            {
              "Not" => {
                "Variable" => "processed",
                "BooleanEquals" => true
              },
              "Next" => "Process"
            }
          ],
          "Default" => "Skip"
        }
      end

      let(:choice_state) { described_class.new("CheckProcessed", definition) }

      before do
        allow(execution).to receive(:logger)
        allow(execution).to receive(:update_output)
        allow(execution).to receive(:add_history_entry)
      end

      it 'matches when NOT condition is false' do
        input = { "processed" => false }
        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Process")
      end

      it 'does not match when NOT condition is true' do
        input = { "processed" => true }
        choice_state.execute(execution, input)
        expect(choice_state.next_state_name).to eq("Skip")
      end
    end
  end

  describe 'type checking conditions' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "data",
            "IsNull" => true,
            "Next" => "NullHandler"
          },
          {
            "Variable" => "data",
            "IsBoolean" => true,
            "Next" => "BooleanHandler"
          },
          {
            "Variable" => "data",
            "IsNumeric" => true,
            "Next" => "NumberHandler"
          },
          {
            "Variable" => "data",
            "IsString" => true,
            "Next" => "StringHandler"
          }
        ],
        "Default" => "DefaultHandler"
      }
    end

    let(:choice_state) { described_class.new("CheckType", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'handles null type check first' do
      input = { "data" => nil }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NullHandler")
    end

    it 'handles boolean type check for true' do
      input = { "data" => true }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("BooleanHandler")
    end

    it 'handles boolean type check for false' do
      input = { "data" => false }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("BooleanHandler")
    end

    it 'handles boolean string type check for "true"' do
      input = { "data" => "true" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("BooleanHandler")
    end

    it 'handles boolean string type check for "false"' do
      input = { "data" => "false" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("BooleanHandler")
    end

    it 'handles numeric type check' do
      input = { "data" => 123 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NumberHandler")
    end

    it 'handles numeric string type check' do
      input = { "data" => "123" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NumberHandler")
    end

    it 'handles float numeric string type check' do
      input = { "data" => "123.45" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NumberHandler")
    end

    it 'handles string type check' do
      input = { "data" => "hello" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("StringHandler")
    end

    it 'uses default for unexpected types like hashes' do
      input = { "data" => { "object" => "value" } }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("DefaultHandler")
    end

    it 'uses default for empty arrays' do
      input = { "data" => [] }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("DefaultHandler")
    end

    it 'uses string handler for non-boolean strings' do
      input = { "data" => "notaboolean" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("StringHandler")
    end

    it 'uses string handler for non-numeric strings' do
      input = { "data" => "notanumber" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("StringHandler")
    end

    it 'does not treat numeric 0 as boolean' do
      input = { "data" => 0 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NumberHandler")
    end

    it 'does not treat numeric 1 as boolean' do
      input = { "data" => 1 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NumberHandler")
    end
  end

  describe 'presence checking conditions' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "required_field",
            "IsPresent" => true,
            "Next" => "Process"
          }
        ],
        "Default" => "Reject"
      }
    end

    let(:choice_state) { described_class.new("CheckPresence", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'matches when field is present and not nil' do
      input = { "required_field" => "some value" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Process")
    end

    it 'does not match when field is nil' do
      input = { "required_field" => nil }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Reject")
    end

    it 'does not match when field is missing' do
      input = { "other_field" => "value" }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Reject")
    end
  end

  describe 'complex order processing workflow' do
    let(:yaml_content) do
      <<~YAML
      Comment: "A workflow that processes orders based on value and inventory"
      StartAt: "CheckOrderValue"
      States:
        CheckOrderValue:
          Type: "Choice"
          Comment: "Check if order value requires special processing"
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
          Result: "High value processed"
          End: true
        
        MediumValueProcessing:
          Type: "Pass"
          Result: "Medium value processed"
          End: true
        
        NormalProcessing:
          Type: "Pass"
          Result: "Normal value processed"
          End: true
        
        InvalidOrder:
          Type: "Fail"
          Cause: "Order total cannot be negative"
          Error: "InvalidOrderError"
    YAML
    end

    let(:state_machine) { StatesLanguageMachine.from_yaml(yaml_content) }

    it 'processes high value orders' do
      input = {
        "order" => {
          "id" => "ORD-001",
          "total" => 1500.00
        }
      }

      execution = state_machine.start_execution(input, "high-value-test")
      execution.run_all

      expect(execution.succeeded?).to be true
      expect(execution.history.map { |h| h[:state_name] }).to include("HighValueProcessing")
    end

    it 'processes medium value orders' do
      input = {
        "order" => {
          "id" => "ORD-002",
          "total" => 250.00
        }
      }

      execution = state_machine.start_execution(input, "medium-value-test")
      execution.run_all

      expect(execution.succeeded?).to be true
      expect(execution.history.map { |h| h[:state_name] }).to include("MediumValueProcessing")
    end

    it 'processes normal value orders' do
      input = {
        "order" => {
          "id" => "ORD-003",
          "total" => 50.00
        }
      }

      execution = state_machine.start_execution(input, "normal-value-test")
      execution.run_all

      expect(execution.succeeded?).to be true
      expect(execution.history.map { |h| h[:state_name] }).to include("NormalProcessing")
    end

    # In the complex order processing workflow test, add debug context:

    it 'handles invalid orders with negative totals' do
      input = {
        "order" => {
          "id" => "ORD-004",
          "total" => -50.00
        }
      }

      # Create a debug logger for this test
      string_io = StringIO.new
      logger = Logger.new(string_io)
      logger.level = Logger::DEBUG

      execution = state_machine.start_execution(input, "invalid-order-test", { logger: logger })
      execution.run_all

      # Print debug info if test fails
      if execution.error != "InvalidOrderError"
        puts "=== DEBUG OUTPUT FOR FAILING TEST ==="
        puts "Execution history: #{execution.history.map { |h| h[:state_name] }}"
        puts "Execution status: #{execution.status}"
        puts "Execution error: #{execution.error}"
        puts "Execution cause: #{execution.cause}"
        puts "Log output:"
        puts string_io.string
      end

      expect(execution.failed?).to be true
      expect(execution.error).to eq("InvalidOrderError")
      expect(execution.cause).to eq("Order total cannot be negative")
    end

    it 'handles negative integer totals' do
      input = {
        "order" => {
          "id" => "ORD-005",
          "total" => -100
        }
      }

      execution = state_machine.start_execution(input, "negative-integer-test")
      execution.run_all

      expect(execution.failed?).to be true
      expect(execution.error).to eq("InvalidOrderError")
    end

    it 'handles negative string totals' do
      input = {
        "order" => {
          "id" => "ORD-006",
          "total" => "-50.00"
        }
      }

      execution = state_machine.start_execution(input, "negative-string-test")
      execution.run_all

      expect(execution.failed?).to be true
      expect(execution.error).to eq("InvalidOrderError")
    end
  end

  describe 'NumericLessThan condition' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericLessThan" => 0,
            "Next" => "Negative"
          }
        ],
        "Default" => "NonNegative"
      }
    end

    let(:choice_state) { described_class.new("CheckNegative", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'matches negative numbers' do
      input = { "value" => -50 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Negative")
    end

    it 'does not match positive numbers' do
      input = { "value" => 50 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NonNegative")
    end

    it 'does not match zero' do
      input = { "value" => 0 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("NonNegative")
    end
  end

  describe 'negative number handling' do
    let(:definition) do
      {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericLessThan" => 0,
            "Next" => "Negative"
          },
          {
            "Variable" => "value",
            "NumericGreaterThan" => 0,
            "Next" => "Positive"
          }
        ],
        "Default" => "Zero"
      }
    end

    let(:choice_state) { described_class.new("CheckSign", definition) }

    before do
      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)
    end

    it 'handles negative numbers' do
      input = { "value" => -50 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Negative")
    end

    it 'handles positive numbers' do
      input = { "value" => 50 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Positive")
    end

    it 'handles zero' do
      input = { "value" => 0 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Zero")
    end

    it 'handles negative float numbers' do
      input = { "value" => -50.5 }
      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Negative")
    end
  end

  describe 'debug negative numbers' do
    let(:string_io) { StringIO.new }
    let(:logger) { Logger.new(string_io) }
    let(:execution) { instance_double('StatesLanguageMachine::Execution', logger: logger) }

    before do
      logger.level = Logger::DEBUG
    end

    it 'debugs negative number comparison' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "NumericLessThan" => 0,
            "Next" => "Negative"
          }
        ],
        "Default" => "NonNegative"
      }

      choice_state = described_class.new("TestChoice", definition)
      input = { "value" => -50 }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== Testing negative number comparison ==="
      choice_state.execute(execution, input)

      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("Negative")
    end
  end

  # Add this test to see if the choice state works in isolation

  describe 'direct choice state test for negative numbers' do
    let(:string_io) { StringIO.new }
    let(:logger) { Logger.new(string_io) }
    let(:execution) { instance_double('StatesLanguageMachine::Execution', logger: logger) }

    before do
      logger.level = Logger::DEBUG
    end

    it 'tests choice state directly with negative order total' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "$.order.total",
            "NumericGreaterThanEquals" => 1000,
            "Next" => "HighValueProcessing"
          },
          {
            "Variable" => "$.order.total",
            "NumericGreaterThanEquals": 100,
            "Next" => "MediumValueProcessing"
          },
          {
            "Variable" => "$.order.total",
            "NumericLessThan" => 0,
            "Next" => "InvalidOrder"
          }
        ],
        "Default": "NormalProcessing"
      }

      choice_state = described_class.new("CheckOrderValue", definition)
      input = {
        "order" => {
          "id" => "ORD-004",
          "total" => -50.00
        }
      }

      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      puts "=== DIRECT CHOICE STATE TEST ==="
      choice_state.execute(execution, input)

      puts "Next state name: #{choice_state.next_state_name}"
      puts "Log output:"
      puts string_io.string

      expect(choice_state.next_state_name).to eq("InvalidOrder")
    end
  end

  describe 'edge cases and error handling' do
    it 'handles nil input values gracefully' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "missing_field",
            "NumericGreaterThan" => 100,
            "Next" => "High"
          }
        ],
        "Default" => "Low"
      }

      choice_state = described_class.new("TestChoice", definition)
      input = { "other_field" => "value" } # missing_field is not present

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Low")
    end

    it 'handles empty input' do
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

      choice_state = described_class.new("TestChoice", definition)

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, {})
      expect(choice_state.next_state_name).to eq("Low")
    end

    it 'handles input with nil values' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "IsPresent" => true,
            "Next" => "Present"
          }
        ],
        "Default" => "Missing"
      }

      choice_state = described_class.new("TestChoice", definition)

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      # Test with explicit nil
      choice_state.execute(execution, { "value" => nil })
      expect(choice_state.next_state_name).to eq("Missing")

      # Test with missing key
      choice_state.execute(execution, { "other" => "data" })
      expect(choice_state.next_state_name).to eq("Missing")
    end

    it 'handles unknown condition types' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            "Variable" => "value",
            "UnknownCondition" => 100,
            "Next" => "High"
          }
        ],
        "Default" => "Low"
      }

      choice_state = described_class.new("TestChoice", definition)
      input = { "value" => 200 }

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Low")
    end

    it 'handles malformed choice definitions' do
      definition = {
        "Type" => "Choice",
        "Choices" => [
          {
            # Missing Variable and condition
            "Next" => "High"
          }
        ],
        "Default" => "Low"
      }

      choice_state = described_class.new("TestChoice", definition)
      input = { "value" => 200 }

      allow(execution).to receive(:logger)
      allow(execution).to receive(:update_output)
      allow(execution).to receive(:add_history_entry)

      choice_state.execute(execution, input)
      expect(choice_state.next_state_name).to eq("Low")
    end
  end
end