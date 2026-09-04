# frozen_string_literal: true

require 'test_helper'

class FHIRPathParitySliceTest < Minitest::Test
  RESOURCE = {
    'resourceType' => 'Patient',
    'name' => [
      { 'use' => 'official', 'given' => %w[Ada Augusta] },
      { 'use' => 'nickname', 'given' => ['Addie'] }
    ]
  }.freeze

  def test_collection_literals_and_arithmetic_follow_precedence
    assert_equal [7], FHIRPath.evaluate({}, '1 + 2 * 3').to_a
    assert_equal [2], FHIRPath.evaluate({}, '10 div 4').to_a
    assert_equal [2], FHIRPath.evaluate({}, '10 mod 4').to_a
    assert_equal [BigDecimal('2.5')], FHIRPath.evaluate({}, '10 / 4').to_a
    assert_equal [2], FHIRPath.evaluate({}, '{1, 2, 3}[1]').to_a
  end

  def test_comparison_and_boolean_operators_work_for_literals
    assert_equal [true], FHIRPath.evaluate({}, '2 < 3 and 4 >= 4').to_a
    assert_equal [true], FHIRPath.evaluate({}, '2 != 3').to_a
    assert_equal [true], FHIRPath.evaluate({}, "'Ada' = 'Ada'").to_a
    assert_equal [true], FHIRPath.evaluate({}, "' Ada ' ~ 'ada'").to_a
    assert_equal [false], FHIRPath.evaluate({}, '2 > 3').to_a
  end

  def test_empty_collections_propagate_through_scalar_operations
    assert_empty FHIRPath.evaluate({}, '{} + 1')
    assert_empty FHIRPath.evaluate({}, '{} = 1')
    assert_equal [true], FHIRPath.evaluate({}, '{} !~ 1').to_a
    assert_equal [true], FHIRPath.evaluate({}, '{} ~ {}').to_a
    assert_equal [false], FHIRPath.evaluate({}, 'false and {}').to_a
    assert_equal [true], FHIRPath.evaluate({}, '{} or true').to_a
    assert_empty FHIRPath.evaluate({}, '{} implies false')
  end

  def test_predicates_expose_this_and_index_focus
    assert_equal ['Addie'], FHIRPath.evaluate(
      RESOURCE, 'Patient.name.where($this.use = \'nickname\').given'
    ).to_a
    assert_equal ['Addie'], FHIRPath.evaluate(
      RESOURCE, 'Patient.name.where($index = 1).given'
    ).to_a
    assert_equal ['Ada'], FHIRPath.evaluate(
      RESOURCE, 'Patient.name.select(given[$index])'
    ).to_a
  end

  def test_index_expression_requires_a_non_negative_integer_singleton
    assert_equal [3], FHIRPath.evaluate({}, '{1, 2, 3}[1 + 1]').to_a
    assert_empty FHIRPath.evaluate({}, '{1, 2, 3}[9]').to_a

    error = assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, "{1, 2}['bad']") }
    assert_equal :expected_integer_index, error.code
  end

  def test_arithmetic_and_comparison_type_errors_are_structured
    arithmetic = assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, "1 + 'x'") }
    assert_equal :expected_number, arithmetic.code
    assert arithmetic.span

    singleton = assert_raises(FHIRPath::SingletonError) { FHIRPath.evaluate({}, '{1, 2} + 1') }
    assert_equal :singleton_required, singleton.code
  end

  def test_parser_rejects_incomplete_and_trailing_expressions
    incomplete = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('1 +') }
    trailing = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('1 2') }
    malformed_collection = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('{1,}') }

    assert_equal :unexpected_token, incomplete.code
    assert_equal :trailing_input, trailing.code
    assert_equal :unexpected_token, malformed_collection.code
    assert_equal 3, incomplete.span.offset
  end

  def test_known_unsupported_operator_is_rejected_at_evaluation
    error = assert_raises(FHIRPath::UnsupportedFeatureError) { FHIRPath.evaluate({}, '1 | 2') }
    assert_equal :unsupported_operator, error.code
  end
end
