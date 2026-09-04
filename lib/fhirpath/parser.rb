# frozen_string_literal: true

require 'bigdecimal'

module FHIRPath
  class Token
    attr_reader :type, :value, :span

    def initialize(type:, value:, span:)
      @type = type
      @value = value
      @span = span
      freeze
    end
  end

  class Lexer
    SINGLE = {
      '.' => :dot, '[' => :left_bracket, ']' => :right_bracket,
      '(' => :left_paren, ')' => :right_paren, ',' => :comma,
      '{' => :left_brace, '}' => :right_brace,
      '=' => :equals, '+' => :plus, '-' => :minus,
      '*' => :multiply, '/' => :divide,
      '<' => :less_than, '>' => :greater_than,
      '|' => :union, '&' => :concatenate, '~' => :equivalent
    }.freeze

    TWO_CHARACTER = {
      '!=' => :not_equals, '<=' => :less_or_equal, '>=' => :greater_or_equal,
      '!~' => :not_equivalent
    }.freeze

    KEYWORD_OPERATORS = %w[and or xor implies div mod].freeze

    def initialize(source)
      @source = source
      @index = 0
    end

    def tokens
      result = []
      until eof?
        skip_whitespace
        break if eof?

        result << next_token
      end
      result << Token.new(type: :eof, value: nil,
                          span: SourceSpan.new(offset: @index, length: 0))
    end

    private

    def eof?
      @index >= @source.length
    end

    def skip_whitespace
      @index += 1 while !eof? && @source[@index] =~ /\s/
    end

    def next_token
      start = @index
      two_character = @source[start, 2]
      if TWO_CHARACTER.key?(two_character)
        @index += 2
        return token(TWO_CHARACTER.fetch(two_character), two_character, start)
      end

      char = @source[@index]
      if SINGLE.key?(char)
        @index += 1
        return token(SINGLE.fetch(char), char, start)
      end
      return string_token(start) if char == "'"
      return external_token(start) if char == '%'
      return variable_token(start) if char == '$'
      return number_token(start) if char =~ /[0-9]/
      return identifier_token(start) if char =~ /[A-Za-z_]/

      raise_error("unexpected character #{char.inspect}", start)
    end

    def string_token(start)
      @index += 1
      value = +''
      until eof?
        char = @source[@index]
        @index += 1
        return token(:string, value, start) if char == "'"

        if char == '\\'
          raise_error('unterminated string escape', @index - 1) if eof?

          value << escaped_character
        else
          value << char
        end
      end
      raise_error('unterminated string literal', start)
    end

    def escaped_character
      escaped = @source[@index]
      @index += 1
      simple = { 'b' => "\b", 'f' => "\f", 'n' => "\n", 'r' => "\r",
                 't' => "\t", '\\' => '\\', "'" => "'", '/' => '/' }
      return simple.fetch(escaped) if simple.key?(escaped)
      return unicode_escape if %w[u U].include?(escaped)

      escaped
    end

    def unicode_escape
      digits = @source[@index, 4]
      raise_error('invalid unicode escape', @index - 1) unless digits&.match?(/\A[0-9A-Fa-f]{4}\z/)

      @index += 4
      [digits.to_i(16)].pack('U')
    end

    def external_token(start)
      @index += 1
      name_start = @index
      @index += 1 while !eof? && @source[@index] =~ /[A-Za-z0-9_]/
      raise_error('external constant requires a name', start) if name_start == @index

      token(:external, @source[name_start...@index], start)
    end

    def variable_token(start)
      @index += 1
      name_start = @index
      @index += 1 while !eof? && @source[@index] =~ /[A-Za-z0-9_]/
      raise_error('variable requires a name', start) if name_start == @index

      token(:variable, @source[name_start...@index], start)
    end

    def number_token(start)
      @index += 1 while !eof? && @source[@index] =~ /[0-9]/
      type = :integer
      if !eof? && @source[@index] == '.' && @source[@index + 1] =~ /[0-9]/
        type = :decimal
        @index += 1
        @index += 1 while !eof? && @source[@index] =~ /[0-9]/
      end
      if !eof? && @source[@index] =~ /[eE]/
        type = :decimal
        @index += 1
        @index += 1 if !eof? && @source[@index] =~ /[+-]/
        exponent_start = @index
        @index += 1 while !eof? && @source[@index] =~ /[0-9]/
        raise_error('decimal exponent requires digits', exponent_start) if exponent_start == @index
      end
      text = @source[start...@index]
      value = type == :integer ? text.to_i : BigDecimal(text)
      token(type, value, start)
    end

    def identifier_token(start)
      @index += 1 while !eof? && @source[@index] =~ /[A-Za-z0-9_]/
      text = @source[start...@index]
      return token(:operator, text.to_sym, start) if KEYWORD_OPERATORS.include?(text)

      token(:identifier, text, start)
    end

    def token(type, value, start)
      Token.new(type: type, value: value,
                span: SourceSpan.new(offset: start, length: @index - start))
    end

    def raise_error(message, start)
      raise ParseError.new(message, code: :invalid_token,
                                    span: SourceSpan.new(offset: start, length: [@index - start, 1].max),
                                    expression: @source)
    end
  end

  class ParsedExpression
    attr_reader :source, :ast, :source_map

    def initialize(source:, ast:)
      @source = source.freeze
      @ast = ast
      @source_map = build_source_map(ast).freeze
      freeze
    end

    private

    def build_source_map(node, result = {})
      return result unless node.is_a?(AST::Node)

      result[node] = node.span
      node.instance_variables.each do |name|
        value = node.instance_variable_get(name)
        if value.is_a?(Array)
          value.each { |child| build_source_map(child, result) }
        else
          build_source_map(value, result)
        end
      end
      result
    end
  end

  class Parser
    PRECEDENCE = {
      implies: 1,
      or: 2, xor: 2,
      and: 3,
      equals: 4, not_equals: 4, equivalent: 4, not_equivalent: 4, union: 4,
      less_than: 5, less_or_equal: 5, greater_than: 5, greater_or_equal: 5,
      plus: 6, minus: 6, concatenate: 6,
      multiply: 7, divide: 7, div: 7, mod: 7
    }.freeze

    BINARY_TOKENS = PRECEDENCE.keys.freeze

    def self.parse(source, capability: Capability.current)
      new(source, capability: capability).parse
    end

    def initialize(source, capability:)
      @source = source.to_s
      @capability = capability
      @tokens = Lexer.new(@source).tokens
      @position = 0
    end

    def parse
      fail_parse('expression cannot be empty', :empty_expression) if current.type == :eof

      ast = parse_expression(0)
      fail_parse('trailing input after expression', :trailing_input) unless current.type == :eof

      ParsedExpression.new(source: @source, ast: ast)
    end

    private

    def parse_expression(min_precedence)
      left = parse_unary
      while (precedence = binary_precedence(current)) && precedence >= min_precedence
        operator_token = advance
        right = parse_expression(precedence + 1)
        left = AST::BinaryExpression.new(left: left, operator: operator_for(operator_token),
                                         right: right,
                                         span: span_between(left.span, right.span))
      end
      left
    end

    def parse_unary
      return parse_postfix(parse_primary) unless %i[plus minus].include?(current.type)

      operator = advance
      operand = parse_unary
      AST::UnaryExpression.new(operator: operator.type,
                               operand: operand,
                               span: span_between(operator.span, operand.span))
    end

    def parse_primary
      token = advance
      node = case token.type
             when :string, :integer, :decimal
               AST::Literal.new(value: token.value, span: token.span)
             when :identifier
               if %w[true false].include?(token.value)
                 AST::Literal.new(value: token.value == 'true', span: token.span)
               else
                 AST::Identifier.new(name: token.value, span: token.span)
               end
             when :variable
               AST::Variable.new(name: token.value, span: token.span)
             when :external
               AST::ExternalConstant.new(name: token.value, span: token.span)
             when :left_brace
               parse_collection(token)
             when :left_paren
               inner = parse_expression(0)
               expect(:right_paren)
               inner
             else
               fail_parse("unexpected token #{token.type}", :unexpected_token, token.span)
             end

      parse_postfix(node)
    end

    def parse_collection(opening)
      elements = []
      unless current.type == :right_brace
        loop do
          elements << parse_expression(0)
          break unless current.type == :comma

          advance
          fail_parse('collection item expected after comma', :unexpected_token) if current.type == :right_brace
        end
      end
      closing = expect(:right_brace)
      AST::CollectionLiteral.new(elements: elements,
                                 span: span_between(opening.span, closing.span))
    end

    def parse_postfix(node)
      loop do
        case current.type
        when :dot
          advance
          name = expect(:identifier)
          node = if current.type == :left_paren
                   parse_function(node, name)
                 else
                   AST::MemberInvocation.new(receiver: node, name: name.value,
                                             span: span_between(node.span, name.span))
                 end
        when :left_bracket
          advance
          index = parse_expression(0)
          closing = expect(:right_bracket)
          node = AST::Indexer.new(receiver: node, index: index,
                                  span: span_between(node.span, closing.span))
        when :left_paren
          unless node.is_a?(AST::Identifier)
            fail_parse('only a function name may be invoked', :unexpected_token,
                       current.span)
          end

          node = parse_function(nil, node)
        else
          break
        end
      end
      node
    end

    def parse_function(receiver, name_token)
      name = name_token.is_a?(AST::Identifier) ? name_token.name : name_token.value
      start = receiver ? receiver.span : name_token.span
      expect(:left_paren)
      arguments = []
      unless current.type == :right_paren
        loop do
          arguments << parse_expression(0)
          break unless current.type == :comma

          advance
        end
      end
      closing = expect(:right_paren)
      AST::FunctionInvocation.new(receiver: receiver, name: name,
                                  arguments: arguments,
                                  span: span_between(start, closing.span))
    end

    def binary_precedence(token)
      return PRECEDENCE[token.type] if BINARY_TOKENS.include?(token.type)
      return PRECEDENCE[token.value] if token.type == :operator && PRECEDENCE.key?(token.value)

      nil
    end

    def operator_for(token)
      token.type == :operator ? token.value : token.type
    end

    def expect(type)
      return advance if current.type == type

      fail_parse("expected #{type}, got #{current.type}", :unexpected_token, current.span)
    end

    def current
      @tokens[@position]
    end

    def advance
      token = current
      @position += 1 unless token.type == :eof
      token
    end

    def span_between(first, last)
      SourceSpan.new(offset: first.offset, length: last.end_offset - first.offset)
    end

    def fail_parse(message, code, span = current.span)
      raise ParseError.new(message, code: code, span: span, expression: @source)
    end
  end
end
