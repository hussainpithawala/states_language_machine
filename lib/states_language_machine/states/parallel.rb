# frozen_string_literal: true

module StatesLanguageMachine
  module States
    class Parallel < Base
      # @return [Array<Hash>] the list of branches to execute in parallel
      attr_reader :branches

      # @param name [String] the name of the state
      # @param definition [Hash] the state definition
      def initialize(name, definition)
        super
        @branches = definition["Branches"] || []
      end

      # @param execution [Execution] the current execution
      # @param input [Hash] the input data for the state
      # @return [Hash] the output data from the state
      def execute(execution, input)
        execution.logger&.info("Executing parallel state: #{@name}")

        results = @branches.map do |branch_def|
          execute_branch(execution, branch_def, input)
        end

        # Combine results (simple merge - real implementation might need more sophistication)
        final_result = results.reduce({}) { |acc, result| deep_merge(acc, result) }

        process_result(execution, final_result)
        final_result
      end

      private

      # Execute a single branch
      # @param execution [Execution] the parent execution
      # @param branch_def [Hash] the branch definition
      # @param input [Hash] the input data
      # @return [Hash] the branch execution result
      # @raise [ExecutionError] if branch execution fails
      def execute_branch(execution, branch_def, input)
        branch_machine = StateMachine.new(branch_def, format: :hash)
        branch_execution = branch_machine.start_execution(
          input,
          "#{execution.name}-branch-#{@branches.index(branch_def)}",
          execution.context
        )
        branch_execution.run_all

        unless branch_execution.succeeded?
          raise ExecutionError.new(@name, "Branch execution failed: #{branch_execution.error}")
        end

        branch_execution.output
      end

      # Validate the parallel state definition
      # @raise [DefinitionError] if the definition is invalid
      def validate!
        super
        raise DefinitionError, "Parallel state '#{@name}' must have at least one branch" if @branches.empty?
      end
    end
  end
end# frozen_string_literal: true

