# frozen_string_literal: true

module FHIRPath
  module AST
    class Node
      attr_reader :span

      def initialize(span:)
        @span = span
        freeze
      end
    end

    class Literal < Node
      attr_reader :value

      def initialize(value:, span:)
        @value = freeze_value(value)
        super(span: span)
      end

      private

      def freeze_value(value)
        case value
        when Array
          value.map { |item| freeze_value(item) }.freeze
        when Hash
          value.each_with_object({}) do |(key, item), copy|
            copy[freeze_value(key)] = freeze_value(item)
          end.freeze
        when String
          value.dup.freeze
        else
          value
        end
      end
    end

    class CollectionLiteral < Node
      attr_reader :elements

      def initialize(elements:, span:)
        @elements = Array(elements).dup.freeze
        super(span: span)
      end
    end

    class Identifier < Node
      attr_reader :name

      def initialize(name:, span:)
        @name = name.freeze
        super(span: span)
      end
    end

    class Variable < Node
      attr_reader :name

      def initialize(name:, span:)
        @name = name.freeze
        super(span: span)
      end
    end

    class ExternalConstant < Node
      attr_reader :name

      def initialize(name:, span:)
        @name = name.freeze
        super(span: span)
      end
    end

    class MemberInvocation < Node
      attr_reader :receiver, :name

      def initialize(receiver:, name:, span:)
        @receiver = receiver
        @name = name.freeze
        super(span: span)
      end
    end

    class Indexer < Node
      attr_reader :receiver, :index

      def initialize(receiver:, index:, span:)
        @receiver = receiver
        @index = index
        super(span: span)
      end
    end

    class FunctionInvocation < Node
      attr_reader :receiver, :name, :arguments

      def initialize(receiver:, name:, arguments:, span:)
        @receiver = receiver
        @name = name.freeze
        @arguments = Array(arguments).dup.freeze
        super(span: span)
      end
    end

    class UnaryExpression < Node
      attr_reader :operator, :operand

      def initialize(operator:, operand:, span:)
        @operator = operator.to_sym
        @operand = operand
        super(span: span)
      end
    end

    class BinaryExpression < Node
      attr_reader :left, :operator, :right

      def initialize(left:, operator:, right:, span:)
        @left = left
        @operator = operator.to_sym
        @right = right
        super(span: span)
      end
    end
  end
end
