# frozen_string_literal: true

module StateMachineHelpers
  def create_simple_choice_machine(choices, default = "DefaultState")
    yaml_content = <<~YAML
      StartAt: "CheckValue"
      States:
        CheckValue:
          Type: "Choice"
          Choices: #{choices.to_json}
          Default: "#{default}"
        DefaultState:
          Type: "Pass"
          End: true
    YAML

    StatesLanguageMachine.from_yaml(yaml_content)
  end

  def create_complex_choice_machine
    yaml_content = <<~YAML
      Comment: "Complex choice workflow for testing"
      StartAt: "CheckOrder"
      States:
        CheckOrder:
          Type: "Choice"
          Choices:
            - Variable: "$.order.total"
              NumericGreaterThan: 1000
              Next: "HighValue"
            - Variable: "$.order.total"
              NumericGreaterThan: 100
              Next: "MediumValue"
          Default: "NormalValue"
        
        HighValue:
          Type: "Pass"
          Result: "High value processed"
          End: true
        
        MediumValue:
          Type: "Pass"
          Result: "Medium value processed"
          End: true
        
        NormalValue:
          Type: "Pass"
          Result: "Normal value processed"
          End: true
    YAML

    StatesLanguageMachine.from_yaml(yaml_content)
  end
end