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
      resource = normalize_resource(resource)
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

    private

    # Raw JSON document strings (the common HTTP-body shape for FHIR) are
    # parsed once per call so Hash/Array resources never pay a JSON cost and
    # the caller's String is left untouched. Detection is deliberately limited
    # to text that opens with `{` or `[` after whitespace; any other String --
    # plain text, JSON scalar text such as "null" or "123", quoted primitives
    # -- keeps its pre-existing meaning as a singleton FHIRPath string value.
    def normalize_resource(resource)
      return resource unless resource.is_a?(String)

      document = resource.dup
      document = document.force_encoding(Encoding::UTF_8) if document.encoding == Encoding::ASCII_8BIT
      unless document.valid_encoding?
        if ascii_json_document?(resource)
          raise JSONInputError.new('resource string is not valid JSON', expression: source)
        end

        return resource
      end
      document = document.encode(Encoding::UTF_8)
      document = document.lstrip
      document = document.delete_prefix("\uFEFF").lstrip
      return resource unless document.start_with?('{', '[')

      JSON.parse(document)
    rescue JSON::ParserError => e
      raise JSONInputError.new(
        'resource string is not valid JSON',
        cause: e, expression: source
      )
    end

    def ascii_json_document?(resource)
      index = resource.bytes.index { |byte| ![9, 10, 13, 32].include?(byte) }
      index && [91, 123].include?(resource.getbyte(index))
    end
  end
end
