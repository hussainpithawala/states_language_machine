require "spec_helper"

RSpec.describe StatesLanguageMachine::States::Wait do
  let(:state_context) { instance_double("StateContext") }
  let(:execution_input) { { "order_id" => 123, "timestamp" => "2023-01-01T10:00:00Z" } }

  before do
    allow(state_context).to receive(:execution_input).and_return(execution_input)
  end

  describe "#initialize" do
    context "with valid wait configuration" do
      it "initializes with seconds wait" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 30,
          "Next" => "NextState"
        }

        wait_state = described_class.new(definition, "TestWait")

        expect(wait_state.state_type).to eq("Wait")
        expect(wait_state.next_state).to eq("NextState")
        expect(wait_state.seconds).to eq(30)
        expect(wait_state.timestamp).to be_nil
        expect(wait_state.seconds_path).to be_nil
        expect(wait_state.timestamp_path).to be_nil
        expect(wait_state.end_state).to be false
      end

      it "initializes with timestamp wait" do
        timestamp = "2023-01-01T10:05:00Z"
        definition = {
          "Type" => "Wait",
          "Timestamp" => timestamp,
          "End" => true
        }

        wait_state = described_class.new(definition, "TestWait")

        expect(wait_state.state_type).to eq("Wait")
        expect(wait_state.end_state).to be true
        expect(wait_state.timestamp).to eq(timestamp)
        expect(wait_state.seconds).to be_nil
      end

      it "initializes with seconds path" do
        definition = {
          "Type" => "Wait",
          "SecondsPath" => "$.wait_seconds",
          "Next" => "NextState"
        }

        wait_state = described_class.new(definition, "TestWait")

        expect(wait_state.seconds_path).to eq("$.wait_seconds")
        expect(wait_state.seconds).to be_nil
      end

      it "initializes with timestamp path" do
        definition = {
          "Type" => "Wait",
          "TimestampPath" => "$.scheduled_time",
          "Next" => "NextState"
        }

        wait_state = described_class.new(definition, "TestWait")

        expect(wait_state.timestamp_path).to eq("$.scheduled_time")
        expect(wait_state.timestamp).to be_nil
      end
    end

    context "with invalid wait configuration" do
      it "raises error when definition is not a hash" do
        expect {
          described_class.new("invalid_definition", "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /State definition must be a Hash/)
      end

      it "raises error when no wait method specified" do
        definition = {
          "Type" => "Wait",
          "Next" => "NextState"
        }

        expect {
          described_class.new(definition, "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /Wait state must specify one of:/)
      end

      it "raises error when multiple wait methods specified" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 30,
          "Timestamp" => "2023-01-01T10:05:00Z",
          "Next" => "NextState"
        }

        expect {
          described_class.new(definition, "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /Wait state can only specify one wait method/)
      end

      it "raises error with invalid seconds value" do
        definition = {
          "Type" => "Wait",
          "Seconds" => -5,
          "Next" => "NextState"
        }

        expect {
          described_class.new(definition, "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /Seconds value must be a positive integer/)
      end

      it "raises error when both End and Next are specified" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 10,
          "End" => true,
          "Next" => "NextState"
        }

        expect {
          described_class.new(definition, "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /Wait state cannot have both 'End' and 'Next'/)
      end

      it "raises error when neither End nor Next are specified" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 10
        }

        expect {
          described_class.new(definition, "InvalidWait")
        }.to raise_error(StatesLanguageMachine::Error, /Wait state must have either 'End' or 'Next'/)
      end
    end
  end

  describe "#execute" do
    context "with seconds wait" do
      it "waits for specified seconds and returns next state" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 1,
          "Next" => "NextState"
        }

        wait_state = described_class.new(definition, "WaitSeconds")

        start_time = Time.now
        result = wait_state.execute(state_context)
        end_time = Time.now

        expect(result.next_state).to eq("NextState")
        expect(result.output).to eq(execution_input)
        expect(result.end_execution).to be false
        expect(end_time - start_time).to be >= 1
      end
    end

    context "with end state" do
      it "completes execution after wait" do
        definition = {
          "Type" => "Wait",
          "Seconds" => 1,
          "End" => true
        }

        wait_state = described_class.new(definition, "WaitEndState")

        result = wait_state.execute(state_context)

        expect(result.end_execution).to be true
        expect(result.next_state).to be_nil
        expect(result.output).to eq(execution_input)
      end
    end

    # Add more execution tests as needed...
  end
end