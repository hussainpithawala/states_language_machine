require 'states_language_machine'

# From YAML file
# state_machine = StatesLanguageMachine.from_yaml_file('workflow.yaml')

# From YAML string
yaml_def = <<~YAML
  StartAt: "ProcessOrder"
  States:
    ProcessOrder:
      Type: "Task"
      Resource: "arn:aws:lambda:us-east-1:123456789012:function:ProcessOrder"
      Next: "CheckInventory"
    CheckInventory:
      Type: "Choice"
      Choices:
        - Variable: "$.in_stock"
          BooleanEquals: true
          Next: "ShipProduct"
      Default: "Backorder"
    ShipProduct:
      Type: "Task"
      Resource: "arn:aws:lambda:us-east-1:123456789012:function:ShipProduct"
      End: true
    Backorder:
      Type: "Fail"
      Cause: "Product out of stock"
      Error: "OutOfStock"
YAML

state_machine = StatesLanguageMachine.from_yaml(yaml_def)

# Execute with custom context
context = {
  logger: Logger.new($stdout),
  task_executor: -> (resource, input) {
    # Custom task execution logic
    { "custom_result" => "executed", resource: resource, input: input }
  }
}

execution = state_machine.start_execution(
  { "order_id" => "123", "in_stock" => true },
  "my-execution-123",
  context
)

execution.run_all

puts execution.succeeded? # => true
puts execution.output     # => Execution output
puts execution.to_json    # => JSON representation of execution