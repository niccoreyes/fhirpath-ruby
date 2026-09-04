# frozen_string_literal: true

require 'test_helper'

class FHIRPathApiContractTest < Minitest::Test
  def test_parsed_and_compiled_boundaries_are_immutable
    parsed = FHIRPath.parse('1 + 2')
    compiled = FHIRPath.compile(parsed)

    assert parsed.frozen?
    assert compiled.frozen?
    assert_equal '1 + 2', compiled.source
    assert_equal [3], compiled.call({}).to_a
  end

  def test_evaluate_preserves_collection_result_policy
    assert_instance_of FHIRPath::Collection, FHIRPath.evaluate({}, '1')
    assert_empty FHIRPath.evaluate({}, '{}')
    assert_nil FHIRPath.evaluate_first({}, '{}')
  end

  def test_external_variable_keys_accept_symbols_without_mutating_input
    variables = { enabled: false }

    assert_equal [false], FHIRPath.evaluate({}, '%enabled', variables: variables).to_a
    assert_equal({ enabled: false }, variables)
  end

  def test_standard_registry_is_immutable_and_custom_registration_is_explicit
    standard = FHIRPath::FunctionRegistry.standard
    custom = standard.register(
      FHIRPath::FunctionSpec.new(
        name: 'double', arity: 0, receiver: :collection,
        implementation: ->(_receiver, _arguments, _context) { [2] }
      )
    )

    refute standard.include?('double')
    assert custom.include?('double')
    assert_raises(ArgumentError) do
      standard.register(FHIRPath::FunctionSpec.new(name: 'count', arity: 0))
    end
  end

  def test_error_serialization_is_stable_at_the_public_boundary
    error = assert_raises(FHIRPath::UnknownFunctionError) do
      FHIRPath.evaluate({}, 'missing()')
    end

    assert_equal :unknown_function, error.code
    assert_equal 'missing()', error.expression
    assert_equal :unknown_function, error.to_h[:code]
  end
end
