# frozen_string_literal: true

require 'test_helper'

class FHIRPathCoreCompatibilityTest < Minitest::Test
  def test_equality_compares_collections_pairwise_in_order
    resource = {
      'left' => [1, 2],
      'same' => [1, 2],
      'permuted' => [2, 1],
      'short' => [1]
    }

    assert_equal [true], FHIRPath.evaluate(resource, 'left = same').to_a
    assert_equal [false], FHIRPath.evaluate(resource, 'left = permuted').to_a
    assert_equal [false], FHIRPath.evaluate(resource, 'left = short').to_a
  end

  def test_equivalence_ignores_collection_order_without_losing_duplicates
    resource = {
      'left' => [1, 1, 2],
      'permuted' => [2, 1, 1],
      'different_duplicates' => [2, 2, 1]
    }

    assert_equal [true], FHIRPath.evaluate(resource, 'left ~ permuted').to_a
    assert_equal [false], FHIRPath.evaluate(resource, 'left ~ different_duplicates').to_a
  end

  def test_equivalence_normalizes_strings_and_least_precise_decimals
    assert_equal [true], FHIRPath.evaluate({}, "'ab c' ~ 'Ab  C'").to_a
    assert_equal [true], FHIRPath.evaluate({}, '1.100 ~ 1.101').to_a
    assert_equal [false], FHIRPath.evaluate({}, '1.1 ~ 1.2').to_a
    assert_equal [true], FHIRPath.evaluate({}, '0 ~ 0.00000010').to_a
    assert_equal [false], FHIRPath.evaluate({}, '11 ~ 10').to_a
  end

  def test_empty_and_not_functions_follow_collection_semantics
    assert_equal [true], FHIRPath.evaluate({}, '{}.empty()').to_a
    assert_equal [false], FHIRPath.evaluate({}, '1.empty()').to_a
    assert_equal [false], FHIRPath.evaluate({}, 'true.not()').to_a
    assert_empty FHIRPath.evaluate({}, '{}.not()')
    assert_equal [true], FHIRPath.evaluate({}, '{}.all(true)').to_a
    assert_equal [false], FHIRPath.evaluate({}, '{1, 2}.all($this > 1)').to_a
  end

  def test_plus_concatenates_strings_but_keeps_numeric_addition
    assert_equal ['ab'], FHIRPath.evaluate({}, "'a' + 'b'").to_a
    assert_equal [3], FHIRPath.evaluate({}, '1 + 2').to_a
    assert_empty FHIRPath.evaluate({}, '{} + 1')
    assert_empty FHIRPath.evaluate({}, "'a' + {}")
  end

  def test_ampersand_concatenates_empty_operands_as_empty_strings
    assert_equal ['ab'], FHIRPath.evaluate({}, "'a' & 'b'").to_a
    assert_equal ['b'], FHIRPath.evaluate({}, "{} & 'b'").to_a
    assert_equal ['a'], FHIRPath.evaluate({}, "'a' & {}").to_a
    assert_equal [''], FHIRPath.evaluate({}, '{} & {}').to_a
  end

  def test_union_is_ordered_and_removes_equal_duplicates
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2) | (2 | 3)').to_a
  end

  def test_union_binds_tighter_than_relational_operators
    expression = FHIRPath.parse('1 | 2 < 3').ast

    assert_equal :less_than, expression.operator
    assert_equal :union, expression.left.operator
  end

  def test_union_and_type_operator_precedence_matches_fhirpath
    union_before_type = FHIRPath.parse('1 | 2 is integer').ast
    assert_equal :union, union_before_type.operator
    assert_equal :is, union_before_type.right.operator

    union_after_type = FHIRPath.parse('1 is integer | 2').ast
    assert_equal :union, union_after_type.operator
    assert_equal :is, union_after_type.left.operator
    assert_equal [1, 2], FHIRPath.evaluate({}, '1 as integer | 2').to_a
  end

  def test_membership_requires_a_singleton_operand
    assert_equal [true], FHIRPath.evaluate({}, '1 in (1 | 2)').to_a
    assert_equal [true], FHIRPath.evaluate({}, '(1 | 2) contains 1').to_a

    error = assert_raises(FHIRPath::SingletonError) do
      FHIRPath.evaluate({}, '(1 | 2) in (1 | 2)')
    end
    assert_equal :singleton_required, error.code
  end

  def test_type_operators_use_builtin_logical_types
    assert_equal [true], FHIRPath.evaluate({}, '1 is integer').to_a
    assert_equal [1], FHIRPath.evaluate({}, '1 as integer').to_a
    assert_empty FHIRPath.evaluate({}, '1 as string')
    assert_empty FHIRPath.evaluate({}, '{} is integer')
  end

  def test_comments_are_ignored_without_changing_expression_boundaries
    assert_equal [3], FHIRPath.evaluate({}, "// comment\n1 + 2").to_a
    assert_equal [3], FHIRPath.evaluate({}, '/* comment */ 1 + 2').to_a

    error = assert_raises(FHIRPath::ParseError) { FHIRPath.parse('/* unterminated 1 + 2') }
    assert_equal :invalid_token, error.code
  end

  def test_string_escapes_reject_unknown_forms_and_support_unicode_surrogate_pairs
    slash = 92.chr
    error = assert_raises(FHIRPath::ParseError) { FHIRPath.parse("'a#{slash}q'") }
    assert_equal :invalid_escape, error.code

    nonstandard = assert_raises(FHIRPath::ParseError) { FHIRPath.parse("'#{slash}U0001F600'") }
    assert_equal :invalid_escape, nonstandard.code
    assert_equal ['😀'], FHIRPath.evaluate({}, "'#{slash}uD83D#{slash}uDE00'").to_a

    high_surrogate = assert_raises(FHIRPath::ParseError) { FHIRPath.parse("'#{slash}uD83D'") }
    assert_equal :invalid_escape, high_surrogate.code
    low_surrogate = assert_raises(FHIRPath::ParseError) { FHIRPath.parse("'#{slash}uDE00'") }
    assert_equal :invalid_escape, low_surrogate.code
  end
end
