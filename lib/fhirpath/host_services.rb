# frozen_string_literal: true

module FHIRPath
  # Optional host work is explicit and absent from pure evaluation by default.
  class HostServices
    attr_reader :constants, :resolve_reference, :terminology, :element_children, :trace

    def self.default
      @default ||= new
    end

    def initialize(constants: nil, resolve_reference: nil, terminology: nil,
                   element_children: nil, trace: nil)
      @constants = constants
      @resolve_reference = resolve_reference
      @terminology = terminology
      @element_children = element_children
      @trace = trace
      freeze
    end

    def constant(name, mode: nil, context: nil)
      return constants.call(name, mode: mode, context: context) if constants

      raise UnknownConstantError.new("unknown external constant: %#{name}",
                                     code: :unknown_constant)
    rescue Error
      raise
    rescue StandardError => e
      raise HostError.new(e.message, cause: e)
    end
  end
end
