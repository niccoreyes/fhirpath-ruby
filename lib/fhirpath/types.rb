# frozen_string_literal: true

require 'bigdecimal'

module FHIRPath
  # Logical type metadata retained independently of the Ruby runtime class.
  class TypeInfo
    attr_reader :logical_type, :namespace, :model_path, :runtime_class

    def initialize(logical_type:, namespace: nil, model_path: nil, runtime_class: nil)
      @logical_type = logical_type.to_s.freeze
      @namespace = namespace&.to_s&.freeze
      @model_path = model_path&.to_s&.freeze
      @runtime_class = runtime_class
      freeze
    end

    def to_h
      { logical_type: logical_type, namespace: namespace,
        model_path: model_path, runtime_class: runtime_class }
    end
  end

  module Value
    class Base
      attr_reader :value, :type_info

      def initialize(value, type_info: nil)
        @value = value
        @type_info = type_info || self.class.default_type_info
        freeze
      end

      def self.default_type_info
        TypeInfo.new(logical_type: name.split('::').last.downcase)
      end

      def to_ruby
        value
      end

      def ==(other)
        other.is_a?(self.class) && other.value == value
      end
      alias eql? ==

      def hash
        [self.class, value].hash
      end
    end

    class String < Base
      def initialize(value, **kwargs)
        super(value.to_s, **kwargs)
      end
    end

    class Integer < Base
      def initialize(value, **kwargs)
        raise ArgumentError, 'FHIRPath integer must be an Integer' unless value.is_a?(::Integer)

        super(value, **kwargs)
      end
    end

    class Decimal < Base
      def initialize(value, **kwargs)
        decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
        super(decimal, **kwargs)
      end
    end
  end

  # A FHIRPath Quantity backed by an explicitly bounded UCUM subset.
  class Quantity < Value::Base
    DEFAULT_SYSTEM = 'http://unitsofmeasure.org'

    attr_reader :unit, :system, :code

    def initialize(value = nil, unit = nil, **kwargs)
      resolved_value = kwargs.fetch(:value, value)
      raise ArgumentError, 'Quantity value is required' if resolved_value.nil?

      @unit = UCUM.validate(kwargs.fetch(:unit, unit))
      @system = (kwargs[:system] || DEFAULT_SYSTEM).to_s.dup.freeze
      @code = (kwargs[:code] || @unit).to_s.dup.freeze
      @calendar = kwargs.fetch(:calendar, false) == true
      super(decimal_value(resolved_value))
    rescue ArgumentError
      raise
    rescue StandardError => e
      raise ArgumentError, "invalid Quantity value: #{e.message}"
    end

    private

    # Coerces a literal or caller-supplied value into a finite BigDecimal.
    def decimal_value(value)
      decimal = value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
      raise ArgumentError, 'Quantity value must be finite' unless decimal.finite?

      decimal
    end

    public

    # True when the unit was written as a FHIRPath calendar duration keyword
    # ("1 month"), as opposed to a UCUM unit ("1 'mo'"). Calendar durations are
    # the only units allowed for Date/DateTime `+`/`-` when the duration is not
    # a fixed number of seconds.
    def calendar?
      @calendar
    end

    def to_ruby
      to_h
    end

    def to_h
      { value: value, unit: unit, system: system, code: code }.freeze
    end

    def compatible?(other)
      other.is_a?(Quantity) && definition.dimensions == other.send(:definition).dimensions
    end

    # Dimension map of the unit, e.g. { length: 1 } for `m`.
    def dimensions
      definition.dimensions
    end

    # Scale of the unit relative to the base atom of its dimension.
    def factor
      definition.factor
    end

    def convert_to(target_unit)
      target = UCUM.validate(target_unit)
      return self if target == unit
      raise ArgumentError, "incompatible Quantity units: #{unit} and #{target}" unless compatible_unit?(target)

      converted = value * definition.factor / UCUM.definition(target).factor
      Quantity.new(value: converted, unit: target, system: system, code: target)
    end

    def ==(other)
      other.is_a?(Quantity) && compatible?(other) && value == other.convert_to(unit).value
    end
    alias eql? ==

    def hash
      [self.class, definition.dimensions, base_value].hash
    end

    private

    def base_value
      value * definition.factor
    end

    def definition
      UCUM.definition(unit)
    end

    def compatible_unit?(target)
      definition.dimensions == UCUM.definition(target).dimensions
    end
  end
end
