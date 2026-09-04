# frozen_string_literal: true

require 'test_helper'

class FHIRPathFoundationTest < Minitest::Test
  RESOURCE = {
    'resourceType' => 'Patient',
    'active' => true,
    'name' => [
      { 'use' => 'official', 'given' => %w[Ada Augusta] },
      { 'use' => 'nickname', 'given' => ['Addie'] }
    ]
  }.freeze

  def test_capability_describes_the_normative_default
    capability = FHIRPath::Capability.current

    assert_equal '2.0.0', capability.fhirpath
    assert_empty capability.trial_use
    assert_empty capability.model_releases
    assert capability.frozen?
  end

  def test_errors_expose_stable_machine_readable_fields
    span = FHIRPath::SourceSpan.new(offset: 2, length: 3)
    error = FHIRPath::ParseError.new('unexpected token', code: :unexpected_token,
                                                         span: span, expression: 'ab?cd')

    assert_equal :unexpected_token, error.code
    assert_equal span, error.span
    assert_equal 'ab?cd', error.expression
    assert_equal({ code: :unexpected_token, message: 'unexpected token',
                   span: span.to_h, expression: 'ab?cd' }, error.to_h)
  end

  def test_collection_keeps_empty_and_singleton_semantics_explicit
    empty = FHIRPath::Collection.empty
    singleton = FHIRPath::Collection.new(['Ada'])

    assert empty.empty?
    assert_equal 1, singleton.count
    assert_equal 'Ada', singleton.singleton!
    assert_raises(FHIRPath::SingletonError) { FHIRPath::Collection.new([1, 2]).singleton! }
  end

  def test_type_info_and_value_objects_preserve_logical_type_metadata
    type_info = FHIRPath::TypeInfo.new(logical_type: 'string', namespace: 'System',
                                       model_path: 'Patient.name.family', runtime_class: String)
    value = FHIRPath::Value::String.new('Ada', type_info: type_info)

    assert_equal 'string', value.type_info.logical_type
    assert_equal 'Patient.name.family', value.type_info.model_path
    assert_equal 'Ada', value.to_ruby
    assert value.frozen?
  end

  def test_ast_nodes_are_immutable_and_keep_source_spans
    span = FHIRPath::SourceSpan.new(offset: 0, length: 4)
    node = FHIRPath::AST::Literal.new(value: String.new('Ada'), span: span)

    assert_equal 'Ada', node.value
    assert node.value.frozen?
    assert_equal span, node.span
    assert node.frozen?
    assert_raises(FrozenError) { node.instance_variable_set(:@value, 'Grace') }
  end

  def test_parse_returns_a_source_preserving_expression
    parsed = FHIRPath.parse('Patient.name[0].given')

    assert_equal 'Patient.name[0].given', parsed.source
    assert_instance_of FHIRPath::AST::MemberInvocation, parsed.ast
    assert_equal 0, parsed.source_map[parsed.ast].offset
  end

  def test_evaluate_supports_plain_hash_navigation_and_collection_results
    result = FHIRPath.evaluate(RESOURCE, 'Patient.name.given')

    assert_instance_of FHIRPath::Collection, result
    assert_equal %w[Ada Augusta Addie], result.to_a
  end

  def test_where_is_evaluated_against_each_nested_focus
    result = FHIRPath.evaluate(RESOURCE, "Patient.name.where(use = 'official').given")

    assert_equal %w[Ada Augusta], result.to_a
  end

  def test_compiled_expression_can_be_reused_without_leaking_context
    program = FHIRPath.compile('Patient.name.family')
    first = { 'resourceType' => 'Patient', 'name' => [{ 'family' => 'Lovelace' }] }
    second = { 'resourceType' => 'Patient', 'name' => [{ 'family' => 'Hopper' }] }

    assert_equal ['Lovelace'], program.evaluate(first).to_a
    assert_equal ['Hopper'], program.evaluate(second).to_a
  end

  def test_evaluate_first_is_an_explicit_scalar_convenience
    assert_equal 'Ada', FHIRPath.evaluate_first(RESOURCE, 'Patient.name.given')
    assert_nil FHIRPath.evaluate_first(RESOURCE, 'Patient.telecom')
  end

  def test_external_constants_can_hold_false_without_falling_through_to_host
    assert_equal [false], FHIRPath.evaluate(RESOURCE, '%enabled', variables: { enabled: false }).to_a
  end

  def test_boolean_operators_preserve_the_empty_collection
    assert_empty FHIRPath.evaluate(RESOURCE, 'Patient.telecom and true')
    assert_equal [true], FHIRPath.evaluate(RESOURCE, 'Patient.telecom or true').to_a
    assert_empty FHIRPath.evaluate(RESOURCE, 'Patient.telecom implies false')
  end

  def test_parser_rejects_invalid_and_trailing_input
    trailing = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('Patient.name ???') }
    invalid = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('Patient.name[bad') }

    assert_equal :invalid_token, trailing.code
    assert_equal :unexpected_token, invalid.code
    assert_equal 'Patient.name[bad', invalid.expression
    assert_equal 16, invalid.span.offset
  end

  def test_missing_external_constants_include_their_source_span
    error = assert_raises(FHIRPath::UnknownConstantError) do
      FHIRPath.evaluate({}, '%missing')
    end

    assert_equal :unknown_constant, error.code
    assert_equal 0, error.span.offset
  end

  def test_plain_model_does_not_invoke_expression_selected_methods
    dangerous = Class.new do
      attr_reader :called

      def dangerous
        @called = true
        'side effect'
      end
    end.new

    assert_empty FHIRPath.evaluate(dangerous, 'dangerous')
    refute dangerous.called
  end

  def test_equality_requires_singleton_operands
    error = assert_raises(FHIRPath::SingletonError) { FHIRPath.evaluate({}, '{1, 2} = 1') }

    assert_equal :singleton_required, error.code
  end

  def test_custom_functions_receive_eagerly_evaluated_collection_arguments
    registry = FHIRPath::FunctionRegistry.standard.register(
      FHIRPath::FunctionSpec.new(
        name: 'increment', arity: 1, parameters: [:value], receiver: :collection,
        implementation: ->(_receiver, arguments, _context) { [arguments.first.singleton! + 1] }
      )
    )

    assert_equal [3], FHIRPath.evaluate({}, 'increment(2)', functions: registry).to_a
  end

  def test_custom_functions_honor_mixed_eager_and_delayed_parameter_metadata
    registry = FHIRPath::FunctionRegistry.standard.register(
      FHIRPath::FunctionSpec.new(
        name: 'mixed', arity: 2, parameters: %i[value expression], receiver: :collection, delayed: true,
        implementation: lambda { |_receiver, arguments, _context|
          eager, delayed = arguments
          [eager.singleton! + (delayed.is_a?(FHIRPath::AST::Variable) ? 1 : 0)]
        }
      )
    )

    assert_equal [3], FHIRPath.evaluate({}, 'mixed(2, $this)', functions: registry).to_a
  end

  def test_custom_functions_are_explicitly_registered
    registry = FHIRPath::FunctionRegistry.standard.register(
      FHIRPath::FunctionSpec.new(
        name: 'triple', arity: 0, receiver: :collection,
        implementation: ->(_receiver, _arguments, _context) { [3] }
      )
    )

    assert_equal [3], FHIRPath.evaluate({}, 'triple()', functions: registry).to_a
  end

  def test_unknown_functions_fail_explicitly
    error = assert_raises(FHIRPath::UnknownFunctionError) do
      FHIRPath.evaluate(RESOURCE, 'Patient.name.missing_function()')
    end

    assert_equal :unknown_function, error.code
  end
end
