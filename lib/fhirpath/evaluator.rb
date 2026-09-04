# frozen_string_literal: true

require 'bigdecimal'

module FHIRPath
  class Evaluator
    def evaluate(node, context)
      evaluate_node(node, context)
    rescue Error => e
      raise e if e.expression

      raise e.class.new(
        e.message,
        code: e.code,
        span: e.span,
        expression: context.options[:expression],
        cause: e.original_cause
      )
    end

    private

    def evaluate_node(node, context)
      case node
      when AST::Literal
        Collection.new([node.value])
      when AST::CollectionLiteral
        Collection.new(node.elements.flat_map { |element| evaluate(element, context).items })
      when AST::Identifier
        identifier(node, context)
      when AST::Variable
        variable(node, context)
      when AST::ExternalConstant
        external_constant(node, context)
      when AST::MemberInvocation
        navigate(node, context)
      when AST::Indexer
        index(node, context)
      when AST::FunctionInvocation
        function(node, context)
      when AST::UnaryExpression
        unary(node, context)
      when AST::BinaryExpression
        binary(node, context)
      else
        raise EvaluationError.new("unsupported AST node: #{node.class}", code: :unsupported_ast)
      end
    end

    def variable(node, context)
      value = case node.name
              when 'this'
                context.focus
              when 'index'
                context.index.nil? ? Collection.empty : Collection.new([context.index])
              when 'total'
                context.total.nil? ? Collection.empty : Collection.new([context.total])
              else
                unless context.variables.key?(node.name)
                  raise EvaluationError.new("unknown variable: $#{node.name}",
                                            code: :unknown_variable, span: node.span)
                end
                Collection.from(context.variables[node.name])
              end
      Collection.from(value)
    end

    def external_constant(node, context)
      value = if context.variables.key?(node.name)
                context.variables[node.name]
              else
                context.host.constant(node.name, context: context)
              end
      Collection.from(value)
    rescue UnknownConstantError, HostError => e
      raise e.class.new(
        e.message,
        code: e.code,
        span: node.span,
        cause: e.original_cause
      )
    end

    def identifier(node, context)
      values = context.focus.items.flat_map do |item|
        if context.model.root_type(item).to_s == node.name
          [item]
        else
          [context.model.property(item, node.name)].flat_map { |value| Collection.from(value).items }
        end
      end
      Collection.new(values)
    rescue NoMethodError => e
      raise ModelError.new("cannot read #{node.name}", code: :model_navigation,
                                                       span: node.span, cause: e)
    end

    def navigate(node, context)
      receiver = evaluate(node.receiver, context)
      values = receiver.items.flat_map do |item|
        value = context.model.property(item, node.name)
        Collection.from(value).items
      end
      Collection.new(values)
    rescue NoMethodError => e
      raise ModelError.new("cannot read #{node.name}", code: :model_navigation,
                                                       span: node.span, cause: e)
    end

    def index(node, context)
      values = evaluate(node.receiver, context)
      return Collection.empty if values.empty?

      index_values = evaluate(node.index, context)
      return Collection.empty if index_values.empty?

      position = require_singleton(index_values, node.index.span)
      unless position.is_a?(::Integer)
        raise TypeError.new('index must be an integer', code: :expected_integer_index,
                                                        span: node.index.span)
      end
      return Collection.empty if position.negative? || position >= values.count

      Collection.new([values.items[position]])
    end

    def function(node, context)
      spec = context.functions.find(node.name)
      validate_function!(node, spec)
      receiver = node.receiver ? evaluate(node.receiver, context) : context.focus
      invoke_function(node, receiver, context, spec)
    end

    def validate_function!(node, spec)
      unless spec
        raise UnknownFunctionError.new(
          "unknown function: #{node.name}", code: :unknown_function, span: node.span
        )
      end
      return if valid_arity?(spec.arity, node.arguments.length)

      raise EvaluationError.new(
        "wrong number of arguments for #{node.name}", code: :invalid_arity, span: node.span
      )
    end

    def invoke_function(node, receiver, context, spec)
      case node.name
      when 'where'
        filter(receiver, node.arguments.first, context)
      when 'select'
        select(receiver, node.arguments.first, context)
      when 'first'
        receiver.empty? ? Collection.empty : Collection.new([receiver.first_item])
      when 'exists'
        exists(receiver, node.arguments.first, context)
      when 'count'
        Collection.new([receiver.count])
      else
        invoke_registered(node, receiver, context, spec)
      end
    end

    def exists(receiver, expression, context)
      return Collection.new([!receiver.empty?]) unless expression

      Collection.new([!filter(receiver, expression, context).empty?])
    end

    def invoke_registered(node, receiver, context, spec)
      unless spec.implementation
        raise UnsupportedFeatureError.new(
          "function #{node.name} has no implementation", code: :unsupported_function,
                                                         span: node.span
        )
      end

      arguments = node.arguments.each_with_index.map do |argument, position|
        parameter = spec.parameters[position]
        delayed = parameter.nil? ? spec.delayed : parameter == :expression
        delayed ? argument : evaluate(argument, context)
      end
      Collection.from(spec.implementation.call(receiver, arguments, context))
    end

    def filter(receiver, predicate, context)
      matching = receiver.items.each_with_index.with_object([]) do |(item, position), result|
        predicate_result = evaluate(
          predicate,
          context.derive(focus: Collection.new([item]), index: position, total: receiver.count)
        )
        result << item if truthy?(predicate_result, predicate.span)
      end
      Collection.new(matching)
    end

    def select(receiver, expression, context)
      Collection.new(receiver.items.each_with_index.flat_map do |item, position|
        evaluate(
          expression,
          context.derive(focus: Collection.new([item]), index: position, total: receiver.count)
        ).items
      end)
    end

    def valid_arity?(arity, actual)
      arity.is_a?(Range) ? arity.cover?(actual) : arity.nil? || arity == actual
    end

    def unary(node, context)
      value = evaluate(node.operand, context)
      return Collection.empty if value.empty?

      number = require_singleton(value, node.operand.span)
      unless numeric?(number)
        raise TypeError.new('unary arithmetic requires a number', code: :expected_number,
                                                                  span: node.span)
      end
      result = node.operator == :minus ? -number : number
      Collection.new([result])
    end

    def binary(node, context)
      case node.operator
      when :equals, :not_equals, :equivalent, :not_equivalent
        equality(node, context)
      when :and, :or, :xor, :implies
        logic(node, context)
      when :plus, :minus, :multiply, :divide, :div, :mod
        arithmetic(node, context)
      when :less_than, :less_or_equal, :greater_than, :greater_or_equal
        comparison(node, context)
      when :union, :concatenate
        raise UnsupportedFeatureError.new("operator #{node.operator} is not supported yet",
                                          code: :unsupported_operator, span: node.span)
      else
        raise UnsupportedFeatureError.new("operator #{node.operator} is not supported",
                                          code: :unsupported_operator, span: node.span)
      end
    end

    def equality(node, context)
      left = evaluate(node.left, context)
      right = evaluate(node.right, context)
      equivalent = %i[equivalent not_equivalent].include?(node.operator)

      return Collection.new([node.operator == :equivalent]) if equivalent && left.empty? && right.empty?
      return Collection.new([node.operator == :not_equivalent]) if equivalent && (left.empty? || right.empty?)
      return Collection.empty if left.empty? || right.empty?

      left_value = require_singleton(left, node.left.span)
      right_value = require_singleton(right, node.right.span)
      equal = if equivalent
                equivalent?(left_value, right_value)
              else
                equal?(left_value, right_value)
              end
      equal = !equal if %i[not_equals not_equivalent].include?(node.operator)
      Collection.new([equal])
    end

    def logic(node, context)
      left = boolean_value(evaluate(node.left, context), node.left.span)
      right = boolean_value(evaluate(node.right, context), node.right.span)
      Collection.from(logical_result(node.operator, left, right))
    end

    def logical_result(operator, left, right)
      case operator
      when :and
        return false if [left, right].include?(false)
        return nil if left.nil? || right.nil?

        true
      when :or
        return true if [left, right].include?(true)
        return nil if left.nil? || right.nil?

        false
      when :xor
        return nil if left.nil? || right.nil?

        left != right
      when :implies
        return true if left == false || right == true
        return nil if left.nil? || right.nil?

        false
      end
    end

    def arithmetic(node, context)
      left = evaluate(node.left, context)
      right = evaluate(node.right, context)
      return Collection.empty if left.empty? || right.empty?

      left_value = require_singleton(left, node.left.span)
      right_value = require_singleton(right, node.right.span)
      unless numeric?(left_value) && numeric?(right_value)
        raise TypeError.new('arithmetic requires numeric values', code: :expected_number,
                                                                  span: node.span)
      end
      raise EvaluationError.new('division by zero', code: :division_by_zero, span: node.span) if zero?(right_value)

      result = case node.operator
               when :plus then left_value + right_value
               when :minus then left_value - right_value
               when :multiply then left_value * right_value
               when :divide then decimal(left_value) / decimal(right_value)
               when :div then (decimal(left_value) / decimal(right_value)).truncate
               when :mod then remainder(left_value, right_value)
               end
      Collection.new([result])
    rescue ::ZeroDivisionError
      raise EvaluationError.new('division by zero', code: :division_by_zero, span: node.span)
    end

    def comparison(node, context)
      left = evaluate(node.left, context)
      right = evaluate(node.right, context)
      return Collection.empty if left.empty? || right.empty?

      left_value = require_singleton(left, node.left.span)
      right_value = require_singleton(right, node.right.span)
      comparison = compare_values(left_value, right_value, node.span)
      result = case node.operator
               when :less_than then comparison.negative?
               when :less_or_equal then comparison <= 0
               when :greater_than then comparison.positive?
               when :greater_or_equal then comparison >= 0
               end
      Collection.new([result])
    end

    def compare_values(left, right, span)
      if numeric?(left) && numeric?(right)
        decimal(left) <=> decimal(right)
      elsif left.is_a?(::String) && right.is_a?(::String)
        left <=> right
      else
        raise TypeError.new('comparison requires compatible values', code: :incompatible_comparison,
                                                                     span: span)
      end
    end

    def equal?(left, right)
      return decimal(left) == decimal(right) if numeric?(left) && numeric?(right)
      return false unless left.class == right.class

      left == right
    end

    def equivalent?(left, right)
      if left.is_a?(::String) && right.is_a?(::String)
        left.strip.casecmp?(right.strip)
      else
        equal?(left, right)
      end
    end

    def numeric?(value)
      value.is_a?(::Integer) || value.is_a?(BigDecimal)
    end

    def decimal(value)
      value.is_a?(BigDecimal) ? value : BigDecimal(value.to_s)
    end

    def remainder(left, right)
      quotient = (decimal(left) / decimal(right)).truncate
      result = left - (quotient * right)
      left.is_a?(BigDecimal) || right.is_a?(BigDecimal) ? decimal(result) : result
    end

    def zero?(value)
      value.zero?
    end

    def require_singleton(collection, span)
      return collection.first_item if collection.singleton?

      raise SingletonError.new('a singleton value was required', code: :singleton_required,
                                                                 span: span)
    end

    def truthy?(collection, span)
      boolean_value(collection, span) == true
    end

    def boolean_value(collection, span)
      return nil if collection.empty?

      value = require_singleton(collection, span)
      return value if [true, false].include?(value)

      raise TypeError.new('expected a Boolean value', code: :expected_boolean, span: span)
    end
  end
end
