# frozen_string_literal: true

require 'test_helper'
require 'bigdecimal'

# Correctness cluster (issues #5, #6, #7, #10) tightened against the FHIRPath 2.0.0
# normative rules. Each group reproduces a previously-wrong evaluator behaviour and
# pins the corrected result, including the empty and singleton-required edge cases.
#
#   #5  Arithmetic with a zero right operand. Only `/`, `div`, `mod` divide; a zero
#       divisor yields an EMPTY collection (never an error). `+`, `-`, `*` operate
#       on zero normally.
#   #6  Union (`|`) eliminates duplicate values from BOTH operands using the `=`
#       (Equals) semantics, preserving first-seen order.
#   #7  Finite JSON/Float values are treated as Decimal, so comparisons, equality
#       and the `is Decimal` type test work; NaN/Infinity are rejected.
#   #10 `in`/`contains` follow the singleton-required and empty-collection rules.

# Issue #5 -- zero right operand must not be treated as a division guard.
class ArithmeticZeroCorrectnessTest < Minitest::Test
  def test_addition_with_zero_returns_the_left_operand
    assert_equal [5], FHIRPath.evaluate({}, '5+0').to_a
    assert_equal [5], FHIRPath.evaluate({}, '5 + 0').to_a
  end

  def test_subtraction_and_multiplication_with_zero_are_normal
    assert_equal [5], FHIRPath.evaluate({}, '5-0').to_a
    assert_equal [0], FHIRPath.evaluate({}, '5*0').to_a
  end

  def test_decimal_zero_operand_is_not_a_division_guard
    # 0.0 parses to a BigDecimal; the arithmetic must treat it as a normal zero
    # operand for +, -, *.
    assert_equal [5], FHIRPath.evaluate({}, '5+0.0').to_a
    assert_equal [0], FHIRPath.evaluate({}, '0.0*5').to_a
    assert_equal [0], FHIRPath.evaluate({}, '5*0.0').to_a
    assert_equal [5], FHIRPath.evaluate({}, '5-0.0').to_a
  end

  def test_zero_left_operand_with_integer_and_decimal
    assert_equal [0], FHIRPath.evaluate({}, '0*5').to_a
    assert_equal [0], FHIRPath.evaluate({}, '0.0*5').to_a
    assert_equal [5], FHIRPath.evaluate({}, '0+5').to_a
    # BigDecimal zero plus an integer yields a decimal value equal to the right
    # operand; the (semantic) result is numeric 5, not an error.
    assert_equal [5], FHIRPath.evaluate({}, '0.0+5').to_a
  end

  def test_division_by_zero_returns_empty_not_an_error
    assert_empty FHIRPath.evaluate({}, '5/0')
    assert_empty FHIRPath.evaluate({}, '5 div 0')
    assert_empty FHIRPath.evaluate({}, '5 mod 0')
    assert_empty FHIRPath.evaluate({}, '0/0')
    assert_empty FHIRPath.evaluate({}, '0.0/0')
  end

  def test_empty_operand_propagation_is_preserved_for_arithmetic
    # A single-input operator on an empty operand yields an empty collection.
    assert_empty FHIRPath.evaluate({}, '{} + 0')
    assert_empty FHIRPath.evaluate({}, '0 + {}')
    assert_empty FHIRPath.evaluate({}, '{} * 0')
  end
end

# Issue #6 -- union eliminates duplicates from BOTH operands using `=` equality.
class UnionCorrectnessTest < Minitest::Test
  def test_union_dedupes_duplicates_within_the_left_operand
    assert_equal [1, 2], FHIRPath.evaluate({}, '{1,1}|{2}').to_a
    assert_equal [1, 2], FHIRPath.evaluate({}, '{1, 1, 1}|{2}').to_a
  end

  def test_union_dedupes_duplicates_within_the_right_operand
    assert_equal [1, 2], FHIRPath.evaluate({}, '{1}|{2,2}').to_a
    assert_equal [1, 2], FHIRPath.evaluate({}, '{1}|{2, 2, 2}').to_a
  end

  def test_union_dedupes_duplicates_across_a_repeating_resource_collection
    # A real Hash/Array resource may hold repeated equal items; `a | b` must still
    # produce distinct values in first-seen order.
    assert_equal [1, 2], FHIRPath.evaluate({ 'a' => [1, 1], 'b' => [2, 2] }, 'a | b').to_a
    # With no `b`, the union is `a` against the empty collection; left duplicates
    # are still removed.
    assert_equal [1], FHIRPath.evaluate({ 'a' => [1, 1] }, 'a | b').to_a
    assert_equal [1, 2], FHIRPath.evaluate({ 'a' => [1], 'b' => [1, 2] }, 'a | b').to_a
  end

  def test_union_preserves_first_seen_order
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '{1, 1, 2}|{2, 3, 1}').to_a
    assert_equal [2, 1, 3], FHIRPath.evaluate({}, '{2, 1}|{1, 3, 2}').to_a
  end

  def test_union_treats_numerically_equal_values_as_duplicates
    # Integer 1 and a decimal 1.0 are equal under the `=` operator.
    assert_equal [1], FHIRPath.evaluate({}, '{1}|{1.0}').to_a
    assert_equal [1], FHIRPath.evaluate({ 'a' => [1], 'b' => [1.0] }, 'a | b').to_a
    assert_equal [1, 2], FHIRPath.evaluate({}, '{1, 2.0}|{1.0, 2}').to_a
  end

  def test_union_with_empty_operand_keeps_the_non_empty_distinct_side
    assert_equal [2], FHIRPath.evaluate({}, '{}|{2, 2}').to_a
    assert_equal [1], FHIRPath.evaluate({}, '{1, 1}|{}').to_a
    assert_empty FHIRPath.evaluate({}, '{}|{}')
  end

  def test_union_does_not_mutate_its_input_operands
    left = [1, 1, 2]
    right = [2, 3]
    assert_equal [1, 2, 3], FHIRPath.evaluate({ 'a' => left, 'b' => right }, 'a | b').to_a
    assert_equal [1, 1, 2], left
    assert_equal [2, 3], right
  end
end

# Issue #7 -- a finite JSON/Float value is treated as a Decimal.
class DecimalFloatCorrectnessTest < Minitest::Test
  def test_float_value_compares_against_an_integer
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.5 }, 'value > 1').to_a
    assert_equal [false], FHIRPath.evaluate({ 'value' => 1.5 }, 'value < 1').to_a
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.5 }, 'value >= 1.5').to_a
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.0 }, 'value = 1').to_a
  end

  def test_float_value_equals_a_decimal_literal
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.5 }, 'value = 1.5').to_a
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.5 }, 'value = 1.50').to_a
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.0 }, 'value = 1.0').to_a
  end

  def test_float_value_is_a_decimal
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.5 }, 'value is Decimal').to_a
    assert_equal [false], FHIRPath.evaluate({ 'value' => 1 }, 'value is Decimal').to_a
    assert_equal [true], FHIRPath.evaluate({ 'value' => 1.0 }, 'value is Decimal').to_a
  end

  def test_float_value_participates_in_arithmetic
    assert_equal [2.5], FHIRPath.evaluate({ 'value' => 1.5 }, 'value + 1').to_a
    assert_equal [0.5], FHIRPath.evaluate({ 'value' => 1.5 }, 'value - 1').to_a
    assert_equal [3], FHIRPath.evaluate({ 'value' => 1.5 }, 'value * 2').to_a
  end

  def test_infinite_or_nan_float_is_not_numeric
    # NaN and Infinity are not finite decimal values and must be rejected.
    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({ 'value' => Float::NAN }, 'value + 1') }
    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({ 'value' => Float::INFINITY }, 'value + 1') }
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({ 'value' => Float::NAN }, 'value > 1')
    end
    assert_equal :incompatible_comparison, error.code
  end

  def test_float_handling_does_not_mutate_the_input_value
    value = 1.5
    FHIRPath.evaluate({ 'value' => value }, 'value + 1')
    assert_equal 1.5, value
  end
end

# Issue #10 -- membership (`in` / `contains`) empty and singleton rules.
class MembershipCorrectnessTest < Minitest::Test
  def test_membership_in_positive_and_negative
    assert_equal [true], FHIRPath.evaluate({}, '2 in {1, 2}').to_a
    assert_equal [true], FHIRPath.evaluate({}, '1 in {1}').to_a
    assert_equal [false], FHIRPath.evaluate({}, '4 in {1, 2}').to_a
  end

  def test_membership_in_with_empty_collections
    # A value in the empty collection is false; both empty is an empty result.
    assert_equal [false], FHIRPath.evaluate({}, '1 in {}').to_a
    assert_empty FHIRPath.evaluate({}, '{} in {}')
    assert_empty FHIRPath.evaluate({}, '{} in {1, 2}')
  end

  def test_membership_contains_positive_and_negative
    assert_equal [true], FHIRPath.evaluate({}, '{1, 2} contains 2').to_a
    assert_equal [false], FHIRPath.evaluate({}, '{1, 2} contains 3').to_a
  end

  def test_membership_contains_with_empty_collections
    assert_equal [false], FHIRPath.evaluate({}, '{} contains 1').to_a
    assert_empty FHIRPath.evaluate({}, '{} contains {}')
    assert_empty FHIRPath.evaluate({}, '{1, 2} contains {}')
  end

  def test_membership_requires_a_singleton_operand_from_both_sides
    # A multi-item operand to `in`/`contains` must raise even when the searched
    # collection is empty.
    error = assert_raises(FHIRPath::SingletonError) do
      FHIRPath.evaluate({}, '{} contains (1 | 2)')
    end
    assert_equal :singleton_required, error.code

    error = assert_raises(FHIRPath::SingletonError) do
      FHIRPath.evaluate({}, '(1 | 2) in {}')
    end
    assert_equal :singleton_required, error.code

    error = assert_raises(FHIRPath::SingletonError) do
      FHIRPath.evaluate({}, '{1, 2} contains (1 | 2)')
    end
    assert_equal :singleton_required, error.code
  end

  def test_membership_uses_semantic_numeric_equality
    assert_equal [true], FHIRPath.evaluate({ 'a' => [1], 'b' => [1.0] }, 'a in b').to_a
    assert_equal [true], FHIRPath.evaluate({ 'a' => [1.0], 'b' => [1] }, 'a in b').to_a
    assert_equal [true], FHIRPath.evaluate({ 'a' => [1.0] }, 'a contains 1').to_a
  end

  def test_membership_does_not_mutate_operand_collections
    # Both operands are singletons here so no singleton error is raised.
    left = [1]
    right = [1, 2]
    FHIRPath.evaluate({ 'a' => left, 'b' => right }, 'a in b')
    assert_equal [1], left
    assert_equal [1, 2], right

    left = [1, 2]
    right = [2]
    FHIRPath.evaluate({ 'a' => left, 'b' => right }, 'a contains 2')
    assert_equal [1, 2], left
    assert_equal [2], right
  end
end
