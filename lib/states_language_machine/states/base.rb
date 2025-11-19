# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Base < State
      # @return [String, nil] the comment describing the state
      attr_reader :comment
      # @return [Hash] the raw state definition
      attr_reader :definition

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super(name, definition)
        @comment = definition["Comment"]
        @definition = definition
      end

      # Validate the state definition
      # @raise [DefinitionError] if the definition is invalid
      def validate!
        # Base validation - can be overridden by subclasses
        if @end_state && @next_state
          raise DefinitionError, "State '#{@name}' cannot have both End and Next"
        end

        unless @end_state || @next_state
          raise DefinitionError, "State '#{@name}' must have either End or Next"
        end
      end

      protected

      # Process the execution result and update history
      # @param execution [Execution] the current execution
      # @param result [Hash] the result to process
      def process_result(execution, result)
        execution.update_output(result)
        execution.add_history_entry(@name, result)
      end


      # Get a value from a nested hash using a dot-separated path
      # @param data [Hash] the data to extract from
      # @param path [String, nil] the dot-separated path
      # @return [Object, nil] the value at the path, or nil if not found
      def get_value_from_path(data, path)
        return data unless path && data

        # Handle nil or empty path
        return data if path.nil? || path.empty?

        # Remove leading '$.' if present (JSONPath format)
        clean_path = path.start_with?('$.') ? path[2..] : path

        # Handle root reference
        return data if clean_path.empty?

        # Split path and traverse
        keys = clean_path.split('.')

        current = data
        keys.each do |key|
          if current.is_a?(Hash) && current.key?(key)
            current = current[key]
          elsif current.is_a?(Array) && key =~ /^\d+$/
            index = key.to_i
            current = current[index] if index < current.length
          else
            # Return nil if any part of the path doesn't exist
            return nil
          end

          # Break if we hit nil
          break if current.nil?
        end

        current
      end

      # Set a value in a nested hash using a dot-separated path
      # @param data [Hash] the data to modify
      # @param path [String] the dot-separated path
      # @param value [Object] the value to set
      # @return [Hash] the modified data
      def set_value_at_path(data, path, value)
        return value unless path

        keys = path.split('.')
        final_key = keys.pop

        target = keys.reduce(data) do |current, key|
          current[key] ||= {}
          current[key]
        end

        target[final_key] = value
        data
      end

      # Deep merge two hashes
      # @param hash1 [Hash] the first hash
      # @param hash2 [Hash] the second hash
      # @return [Hash] the merged hash
      def deep_merge(hash1, hash2)
        hash1.merge(hash2) do |key, old_val, new_val|
          if old_val.is_a?(Hash) && new_val.is_a?(Hash)
            deep_merge(old_val, new_val)
          else
            new_val
          end
        end
      end

      # Apply input path to filter input data
      # @param input [Hash] the input data
      # @param input_path [String, nil] the input path to apply
      # @return [Hash] the filtered input data
      def apply_input_path(input, input_path)
        return input unless input_path
        get_value_from_path(input, input_path) || {}
      end

      # Apply output path to filter output data
      # @param output [Hash] the output data
      # @param output_path [String, nil] the output path to apply
      # @return [Hash] the filtered output data
      def apply_output_path(output, output_path)
        return output unless output_path
        set_value_at_path({}, output_path, output)
      end

      # Apply result path to merge result with input
      # @param input [Hash] the original input data
      # @param result [Hash] the result data
      # @param result_path [String, nil] the result path to apply
      # @return [Hash] the merged data
      def apply_result_path(input, result, result_path)
        return result unless result_path

        if result_path.nil?
          input
        else
          set_value_at_path(input.dup, result_path, result)
        end
      end
    end
  end
end