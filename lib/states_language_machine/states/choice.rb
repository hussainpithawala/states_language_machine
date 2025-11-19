# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Choice < Base
      attr_reader :choices, :default

      def initialize(name, definition)
        super
        @choices = definition["Choices"] || []
        @default = definition["Default"]
        @evaluated_next_state = nil
      end

      def execute(execution, input)
        execution.logger&.info("Executing choice state: #{@name}")

        @evaluated_next_state = evaluate_choices(input, execution.logger)

        execution.logger&.info("Selected next state: #{@evaluated_next_state}")
        process_result(execution, input)
        input
      end

      def next_state_name(input = nil)
        return nil if end_state?
        return @evaluated_next_state if @evaluated_next_state
        input ? evaluate_choices(input) : @default
      end

      private

      def evaluate_choices(input, logger = nil)
        @choices.each do |choice|
          puts choice
          result = evaluate_choice(choice, input, logger)
          puts result
          if result
            return choice["Next"]
          end
        end
        @default
      end

      def evaluate_choice(choice, input, logger = nil)
        if choice["And"]
          return choice["And"].all? { |condition| evaluate_choice(condition, input, logger) }
        end

        if choice["Or"]
          return choice["Or"].any? { |condition| evaluate_choice(condition, input, logger) }
        end

        if choice["Not"]
          return !evaluate_choice(choice["Not"], input, logger)
        end

        condition_type = choice.keys.find { |k| !["Variable", "Next", "Comment"].include?(k) }
        return false unless condition_type

        variable_path = choice["Variable"]
        expected_value = choice[condition_type]
        actual_value = get_value_from_path(input, variable_path)

        evaluate_simple_condition(condition_type, actual_value, expected_value, logger)
      end

      # Evaluate a simple condition
      # @param condition_type [String] the type of condition
      # @param actual_value [Object] the actual value from input
      # @param expected_value [Object] the expected value from condition
      # @param logger [Logger, nil] the logger for debug output
      # @return [Boolean] whether the condition matches
      def evaluate_simple_condition(condition_type, actual_value, expected_value, logger = nil)
        puts condition_type
        case condition_type
        when "NumericEquals"
          actual_num = to_number(actual_value)
          expected_num = to_number(expected_value)
          return false if actual_num.nil? || expected_num.nil?
          actual_num == expected_num
        when "NumericLessThan"
          actual_num = to_number(actual_value)
          expected_num = to_number(expected_value)
          return false if actual_num.nil? || expected_num.nil?
          puts "result of NumericLessThan", actual_num < expected_num
          actual_num < expected_num
        when "NumericGreaterThan"
          actual_num = to_number(actual_value)
          expected_num = to_number(expected_value)
          return false if actual_num.nil? || expected_num.nil?
          actual_num > expected_num
        when "NumericLessThanEquals"
          actual_num = to_number(actual_value)
          expected_num = to_number(expected_value)
          return false if actual_num.nil? || expected_num.nil?
          actual_num <= expected_num
        when "NumericGreaterThanEquals"
          actual_num = to_number(actual_value)
          expected_num = to_number(expected_value)
          return false if actual_num.nil? || expected_num.nil?
          actual_num >= expected_num
        when "StringEquals"
          actual_value.to_s == expected_value.to_s
        when "BooleanEquals"
          to_boolean(actual_value) == to_boolean(expected_value)
        when "IsNull"
          actual_value.nil?
        when "IsPresent"
          !actual_value.nil?
        when "IsString"
          actual_value.is_a?(String)
        when "IsNumeric"
          !!to_number(actual_value)
        when "IsBoolean"
          actual_value.is_a?(TrueClass) || actual_value.is_a?(FalseClass) ||
            (actual_value.is_a?(String) && ["true", "false"].include?(actual_value.downcase))
        else
          false
        end
      end

      def to_number(value)
        return value if value.is_a?(Numeric)
        return nil if value.nil?

        if value.is_a?(String)
          Float(value) rescue nil
        else
          Float(value) rescue nil
        end
      end

      def to_boolean(value)
        return value if [true, false].include?(value)
        value.to_s.downcase == "true"
      end

      def validate!
        # Skip base validation for choice states
      end
    end
  end
end