# frozen_string_literal: true

module FHIRPath
  # Explicit boundary for external constant lookup. Implementations may perform
  # I/O, but only when an expression requests a constant through this object.
  class ConstantProvider
    def fetch(_name, mode:, context:)
      raise NotImplementedError, 'constant providers must implement #fetch'
    end

    def call(name, mode:, context:)
      fetch(name, mode: mode, context: context)
    end
  end

  # Optional host work is explicit and absent from pure evaluation by default.
  class HostServices
    attr_reader :constants, :constant_provider, :resolve_reference, :terminology, :element_children, :trace

    def self.default
      @default ||= new
    end

    # rubocop:disable Metrics/ParameterLists
    def initialize(constants: nil, constant_provider: nil, resolve_reference: nil, terminology: nil,
                   element_children: nil, trace: nil)
      raise ArgumentError, 'provide either constants or constant_provider, not both' if constants && constant_provider

      @constant_provider = constant_provider || constants
      @constants = @constant_provider
      @resolve_reference = resolve_reference
      @terminology = terminology
      @element_children = element_children
      @trace = trace
      freeze
    end

    def constant(name, mode: nil, context: nil)
      unless constants
        raise UnknownConstantError.new("unknown external constant: %#{name}",
                                       code: :unknown_constant)
      end

      begin
        constants.call(name, mode: mode, context: context)
      rescue StandardError
        raise HostError.new('constant provider failed', code: :host_error), cause: nil
      end
    end
    # rubocop:enable Metrics/ParameterLists
  end
end
