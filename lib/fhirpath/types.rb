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
end
