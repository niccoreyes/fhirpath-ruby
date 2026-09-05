# frozen_string_literal: true

module FHIRPath
  FunctionSpec = Struct.new(:name, :arity, :parameters, :receiver, :delayed,
                            :implementation, keyword_init: true) do
    def initialize(**kwargs)
      super
      self.name = name.to_s.freeze
      self.parameters = Array(parameters).map(&:to_sym).freeze
      freeze
    end
  end

  class FunctionRegistry
    STANDARD_NAMES = %w[
      where select first last tail take skip
      exists count empty not all
      allTrue anyTrue allFalse anyFalse
      sum avg max min
    ].freeze
    DELAYED_NAMES = %w[where select exists all].freeze

    def self.standard
      @standard ||= new(STANDARD_NAMES.each_with_object({}) do |name, specs|
        specs[name] = standard_spec(name)
      end)
    end

    def self.standard_spec(name)
      FunctionSpec.new(
        name: name,
        arity: standard_arity(name),
        parameters: DELAYED_NAMES.include?(name) ? [:expression] : [],
        receiver: :collection,
        delayed: DELAYED_NAMES.include?(name)
      )
    end

    def self.standard_arity(name)
      return 0..1 if name == 'exists'
      return 1 if name == 'all' || %w[where select take skip].include?(name)

      0
    end
    private_class_method :standard_arity, :standard_spec

    def initialize(specs = {})
      @specs = specs.transform_keys(&:to_s).dup.freeze
      freeze
    end

    def find(name)
      @specs[name.to_s]
    end

    def include?(name)
      !find(name).nil?
    end

    def register(spec)
      key = spec.name.to_s
      raise ArgumentError, "cannot replace standard function: #{key}" if STANDARD_NAMES.include?(key)

      self.class.new(@specs.merge(key => spec))
    end

    def names
      @specs.keys.freeze
    end
  end
end
