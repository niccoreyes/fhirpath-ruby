# frozen_string_literal: true

require_relative 'fhirpath/version'
require_relative 'fhirpath/source_span'
require_relative 'fhirpath/errors'
require_relative 'fhirpath/capability'
require_relative 'fhirpath/collection'
require_relative 'fhirpath/types'
require_relative 'fhirpath/ast'
require_relative 'fhirpath/model'
require_relative 'fhirpath/models_r4'
require_relative 'fhirpath/model_registry'
require_relative 'fhirpath/host_services'
require_relative 'fhirpath/functions'
require_relative 'fhirpath/evaluation_context'
require_relative 'fhirpath/parser'
require_relative 'fhirpath/evaluator'
require_relative 'fhirpath/compiled_expression'

# Public entry point for the Ruby FHIRPath implementation.
module FHIRPath
  class << self
    def version
      VERSION
    end

    def parse(expression, capability: Capability.current)
      Parser.parse(expression, capability: capability)
    end

    def model(release)
      ModelRegistry.fetch(release)
    end

    def available_models
      ['R4'].freeze
    end

    def compile(expression, model: nil, capability: Capability.current,
                functions: FunctionRegistry.standard)
      parsed = expression.is_a?(ParsedExpression) ? expression : parse(expression, capability: capability)
      CompiledExpression.new(parsed: parsed, model: resolve_model(model, capability),
                             functions: functions, capability: capability)
    end

    def evaluate(resource, expression, variables: {}, model: nil,
                 capability: Capability.current, functions: FunctionRegistry.standard,
                 options: {}, host: nil)
      compile(expression, model: model, capability: capability, functions: functions)
        .evaluate(resource, variables: variables, host: host, options: options)
    end

    def evaluate_first(resource, expression, variables: {}, model: nil,
                       capability: Capability.current, functions: FunctionRegistry.standard,
                       options: {}, host: nil)
      evaluate(resource, expression, variables: variables, model: model,
                                     capability: capability, functions: functions, options: options, host: host)
        .first_item
    end

    private

    def resolve_model(model, capability)
      return PlainModel.new if model.nil?
      return model unless model.is_a?(Symbol) || model.is_a?(String)

      provider = ModelRegistry.fetch(model)
      unless capability.supports_model?(provider.class::RELEASE)
        raise UnsupportedFeatureError.new(
          "FHIR model release is not enabled: #{provider.class::RELEASE}",
          code: :unsupported_model_release
        )
      end
      provider
    end
  end
end
