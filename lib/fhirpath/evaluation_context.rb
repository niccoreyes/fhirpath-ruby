# frozen_string_literal: true

module FHIRPath
  # Per-call state. Compiled expressions never retain a context or resource.
  class EvaluationContext
    attr_reader :root, :focus, :variables, :model, :host, :functions, :capability,
                :options, :index, :total

    def initialize(root:, focus: nil, variables: {}, model: nil, host: nil,
                   functions: nil, capability: nil, options: {}, index: nil, total: nil)
      @root = Collection.from(root)
      @focus = Collection.from(focus || root)
      @variables = variables.transform_keys(&:to_s).freeze
      @model = model || PlainModel.new
      @host = host || HostServices.default
      @functions = functions || FunctionRegistry.standard
      @capability = capability || Capability.current
      @options = options.dup.freeze
      @index = index
      @total = total
      freeze
    end

    def derive(focus:, variables: self.variables, index: nil, total: nil)
      self.class.new(root: root, focus: focus, variables: variables, model: model,
                     host: host, functions: functions, capability: capability,
                     options: options, index: index, total: total)
    end
  end
end
