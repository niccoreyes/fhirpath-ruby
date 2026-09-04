# frozen_string_literal: true

module FHIRPath
  class Error < StandardError
    attr_reader :code, :span, :expression, :original_cause

    def initialize(message = nil, code:, span: nil, expression: nil, cause: nil)
      super(message)
      @code = code.to_sym
      @span = span
      @expression = expression
      @original_cause = cause
    end

    def to_h
      data = { code: code, message: message }
      data[:span] = span.to_h if span
      data[:expression] = expression if expression
      data
    end
  end

  class ParseError < Error
    def initialize(message = 'invalid expression', code: :parse_error, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class EvaluationError < Error
    def initialize(message = 'expression could not be evaluated', code: :evaluation_error, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class SingletonError < EvaluationError
    def initialize(message = 'a singleton value was required', code: :singleton_required, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class TypeError < EvaluationError
    def initialize(message = 'value has an incompatible type', code: :type_error, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class UnknownFunctionError < EvaluationError
    def initialize(message = 'unknown function', code: :unknown_function, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class UnknownConstantError < EvaluationError
    def initialize(message = 'unknown external constant', code: :unknown_constant, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class ModelError < EvaluationError
    def initialize(message = 'model navigation failed', code: :model_error, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class HostError < EvaluationError
    def initialize(message = 'host service failed', code: :host_error, **kwargs)
      super(message, code: code, **kwargs)
    end
  end

  class UnsupportedFeatureError < EvaluationError
    def initialize(message = 'feature is not supported', code: :unsupported_feature, **kwargs)
      super(message, code: code, **kwargs)
    end
  end
end
