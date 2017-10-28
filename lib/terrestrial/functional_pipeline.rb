module Terrestrial
  class FunctionalPipeline
    def self.from_array(steps = [])
      new(steps.map { |name, func| Step.new(name, func) })
    end

    def initialize(steps = [])
      @steps = steps
    end

    def call(args, &block)
      result = execution_result([[:input, args]], &block)

      [result.last.last, result]
    end

    def describe
      @steps.map(&:name)
    end

    def append(name, func)
      self.class.new(@steps + [Step.new(name, func)])
    end

    def take_until(step_name)
      step = @steps.detect { |step| step.name == step_name }
      last_step_index = @steps.index(step)
      steps = @steps.slice(0..last_step_index)

      self.class.new(steps)
    end

    def drop_until(step_name)
      step = @steps.detect { |step| step.name == step_name }
      first_step_index = @steps.index(step) + 1
      steps = @steps.slice(first_step_index..-1)

      self.class.new(steps)
    end

    private

    def execution_result(initial_state, &block)
      @steps.reduce(initial_state) { |state, step|
        new_value = step.call(state.last.last)
        block && block.call(step.name, new_value)
        state + [ [step.name, new_value] ]
      }
    end

    class Step
      def initialize(name, func)
        @name = name
        @func = func
      end

      attr_reader :name, :func

      def call(*args, &block)
        func.call(*args, &block)
      end
    end
  end
end
