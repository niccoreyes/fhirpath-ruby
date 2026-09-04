# frozen_string_literal: true

module FHIRPath
  # Reusable immutable parse/evaluation boundary.
  class CompiledExpression
    attr_reader :source, :parsed, :ast, :model, :functions, :capability

    def initialize(parsed:, model:, functions:, capability:)
      @parsed = parsed
      @source = parsed.source
      @ast = parsed.ast
      @model = model
      @functions = functions
      @capability = capability
      freeze
    end

    def evaluate(resource, variables: {}, host: nil, options: {})
      context = EvaluationContext.new(
        root: resource,
        variables: variables,
        model: model,
        host: host,
        functions: functions,
        capability: capability,
        options: options.merge(expression: source)
      )
      Evaluator.new.evaluate(ast, context)
    end

    def call(resource, **kwargs)
      evaluate(resource, **kwargs)
    end
  end
end
