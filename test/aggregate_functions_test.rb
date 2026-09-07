# frozen_string_literal: true

require 'test_helper'

class FHIRPathCountFunctionTest < Minitest::Test
  # --- count() ---

  def test_count_of_items_returns_integer_count
    assert_equal [3], FHIRPath.evaluate({}, '(1 | 2 | 3).count()').to_a
    assert_equal [4], FHIRPath.evaluate({}, "('a' | 'b' | 'c' | 'd').count()").to_a
  end

  def test_count_of_empty_collection_returns_zero
    assert_equal [0], FHIRPath.evaluate({}, '{}.count()').to_a
  end

  def test_count_of_singleton_returns_one
    assert_equal [1], FHIRPath.evaluate({}, '1.count()').to_a
  end

  def test_count_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [3], FHIRPath.evaluate(resource, 'g.count()').to_a
  end

  def test_count_counts_mixed_type_items
    resource = { 'g' => [1, 'a', true, false] }
    assert_equal [4], FHIRPath.evaluate(resource, 'g.count()').to_a
  end

  def test_count_requires_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).count(1)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_count_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.count()')
    assert_equal [1, 2, 3], resource['g']
  end
end

class FHIRPathAggregateFunctionsTest < Minitest::Test
  # --- sum() ---

  def test_sum_of_integers_returns_integer_sum
    assert_equal [6], FHIRPath.evaluate({}, '(1 | 2 | 3).sum()').to_a
    assert_equal [0], FHIRPath.evaluate({}, '(0 | 0).sum()').to_a
  end

  def test_sum_of_decimals_returns_decimal_sum
    assert_equal [BigDecimal('15.0')], FHIRPath.evaluate({}, '(1.0 | 2.0 | 3.0 | 4.0 | 5.0).sum()').to_a
    assert_equal [BigDecimal('3.5')], FHIRPath.evaluate({}, '(1.5 | 2.0).sum()').to_a
  end

  def test_sum_mixes_integer_and_decimal_items_in_decimal
    # Numeric promotion follows the engine's arithmetic/equality conventions
    # (Integer 1 + Decimal 2.5 is Decimal 3.5).
    assert_equal [BigDecimal('3.5')], FHIRPath.evaluate({}, '(1 | 2.5).sum()').to_a
  end

  def test_sum_of_single_item_returns_that_item
    assert_equal [7], FHIRPath.evaluate({}, '7.sum()').to_a
    assert_equal [BigDecimal('2.5')], FHIRPath.evaluate({}, '2.5.sum()').to_a
  end

  def test_sum_of_empty_collection_is_empty
    assert_empty FHIRPath.evaluate({}, '{}.sum()')
  end

  def test_sum_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [6], FHIRPath.evaluate(resource, 'g.sum()').to_a
  end

  def test_sum_rejects_non_numeric_items
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({}, "('a' | 'b').sum()")
    end
    assert_equal :expected_number, error.code

    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, "'a'.sum()") }
    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, '(true | false).sum()') }
  end

  def test_sum_requires_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).sum(1)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_sum_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.sum()')
    assert_equal [1, 2, 3], resource['g']
  end

  # --- avg() ---

  def test_avg_of_decimals_returns_decimal_average
    assert_equal [BigDecimal('5.0')], FHIRPath.evaluate({}, '(5.5 | 4.7 | 4.8).avg()').to_a
  end

  def test_avg_of_integers_is_implicitly_decimal
    # Integers convert to Decimal before averaging (FHIRPath 3.0.0 STU3).
    assert_equal [BigDecimal('2.5')], FHIRPath.evaluate({}, '(1 | 2 | 3 | 4).avg()').to_a
    assert_equal [BigDecimal('5.0')], FHIRPath.evaluate({}, '5.avg()').to_a
  end

  def test_avg_of_single_decimal_returns_that_decimal
    assert_equal [BigDecimal('2.5')], FHIRPath.evaluate({}, '2.5.avg()').to_a
  end

  def test_avg_of_empty_collection_is_empty
    assert_empty FHIRPath.evaluate({}, '{}.avg()')
  end

  def test_avg_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [BigDecimal('2.0')], FHIRPath.evaluate(resource, 'g.avg()').to_a
  end

  def test_avg_rejects_non_numeric_items
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({}, "('a' | 'b').avg()")
    end
    assert_equal :expected_number, error.code

    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, "'a'.avg()") }
  end

  def test_avg_requires_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).avg(1)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_avg_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.avg()')
    assert_equal [1, 2, 3], resource['g']
  end
end

class FHIRPathExtremumFunctionsTest < Minitest::Test
  # --- max() / min() ---

  def test_max_of_numerics_returns_maximum_item
    assert_equal [8], FHIRPath.evaluate({}, '(2 | 4 | 8 | 6).max()').to_a
    assert_equal [-1], FHIRPath.evaluate({}, '(-3 | -1 | -2).max()').to_a
  end

  def test_min_of_numerics_returns_minimum_item
    assert_equal [2], FHIRPath.evaluate({}, '(2 | 4 | 8 | 6).min()').to_a
    assert_equal [-3], FHIRPath.evaluate({}, '(-3 | -1 | -2).min()').to_a
  end

  def test_max_and_min_compare_across_integer_and_decimal
    assert_equal [BigDecimal('2.5')], FHIRPath.evaluate({}, '(1 | 2.5).max()').to_a
    assert_equal [1], FHIRPath.evaluate({}, '(1 | 2.5).min()').to_a
  end

  def test_max_and_min_of_strings_order_lexicographically
    assert_equal ['c'], FHIRPath.evaluate({}, "('b' | 'a' | 'c').max()").to_a
    assert_equal ['a'], FHIRPath.evaluate({}, "('b' | 'a' | 'c').min()").to_a
  end

  def test_max_and_min_of_single_item_return_that_item
    assert_equal [7], FHIRPath.evaluate({}, '7.max()').to_a
    assert_equal [7], FHIRPath.evaluate({}, '7.min()').to_a
    assert_equal ['a'], FHIRPath.evaluate({}, "'a'.min()").to_a
  end

  def test_max_and_min_of_empty_collection_are_empty
    assert_empty FHIRPath.evaluate({}, '{}.max()')
    assert_empty FHIRPath.evaluate({}, '{}.min()')
  end

  def test_max_and_min_on_navigation_result
    resource = { 'g' => [3, 1, 2] }
    assert_equal [3], FHIRPath.evaluate(resource, 'g.max()').to_a
    assert_equal [1], FHIRPath.evaluate(resource, 'g.min()').to_a
  end

  def test_max_and_min_reject_incompatible_item_types
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({}, "(1 | 'a').max()")
    end
    assert_equal :incompatible_comparison, error.code

    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, "(true | 'a').min()") }
    assert_raises(FHIRPath::TypeError) { FHIRPath.evaluate({}, '(true | false).max()') }
  end

  def test_max_and_min_require_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).max(1)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_max_and_min_do_not_mutate_input
    resource = { 'g' => [3, 1, 2] }
    FHIRPath.evaluate(resource, 'g.max()')
    FHIRPath.evaluate(resource, 'g.min()')
    assert_equal [3, 1, 2], resource['g']
  end
end

class FHIRPathAggregateCapabilitySurfaceTest < Minitest::Test
  MARKER = FHIRPath::Capability::STU3_AGGREGATE_FUNCTIONS

  def test_current_capability_declares_the_stu3_aggregate_subset_as_trial_use
    capability = FHIRPath::Capability.current

    # count() is normative 2.0.0 (collection-functions); sum/avg/max/min are a
    # surfaced STU3-subset exception, never folded into the 2.0 claims.
    assert_equal '2.0.0', capability.fhirpath
    assert_includes capability.capability_set, 'collection-functions'
    refute_includes capability.capability_set, MARKER
    assert_includes capability.trial_use, MARKER
    assert capability.supports?(MARKER)
    assert_includes capability.to_h[:trial_use], MARKER
    assert_equal '2.0.0', capability.to_h[:fhirpath]
  end

  def test_strict_2_0_capability_declaration_omits_the_stu3_subset
    strict = FHIRPath::Capability.new(trial_use: [])

    assert_empty strict.trial_use
    refute strict.supports?(MARKER)
    assert_equal '2.0.0', strict.fhirpath
  end

  def test_trial_use_is_a_surface_declaration_not_a_registry_gate
    # The marker reports the shipped default-on exception. It is descriptive:
    # the standard registry still evaluates the functions for a strict-2.0
    # declaration. Registry-level enforcement is not part of this capability
    # surface and is documented as such in docs/api.md.
    strict = FHIRPath::Capability.new(trial_use: [])

    assert_equal [6], FHIRPath.evaluate({}, '(1 | 2 | 3).sum()', capability: strict).to_a
  end

  # --- aggregate() ---

  def test_aggregate_sum_with_init_zero
    # sum can be expressed as value.aggregate($this + $total, 0)
    assert_equal [6], FHIRPath.evaluate({}, '(1 | 2 | 3).aggregate($this + $total, 0)').to_a
  end

  def test_aggregate_min_with_custom_init
    # min can be expressed as value.aggregate(iif($total.empty(), $this, iif($this < $total, $this, $total)))
    expr = '(3 | 1 | 4 | 1 | 5).aggregate(iif($total.empty(), $this, iif($this < $total, $this, $total)))'
    assert_equal [1], FHIRPath.evaluate({}, expr).to_a
  end

  def test_aggregate_max_with_custom_init
    # max can be expressed similarly
    expr = '(3 | 1 | 4 | 1 | 5).aggregate(iif($total.empty() or $this > $total, $this, $total))'
    assert_equal [5], FHIRPath.evaluate({}, expr).to_a
  end

  def test_aggregate_average_via_sum_and_count
    # average can be computed as sum / count using a nested expression
    # First compute sum, then divide by count
    sum_result = FHIRPath.evaluate({}, '(1 | 2 | 3).aggregate($this + $total, 0)').to_a.first
    assert_equal 6, sum_result
    # Then count and divide manually (since division needs proper context)
    assert_equal BigDecimal('2.0'), BigDecimal(sum_result) / 3
  end

  def test_aggregate_optional_init_argument
    # init argument is optional - should default to empty collection
    # For sum, this means empty collection returns empty
    assert_equal [], FHIRPath.evaluate({}, '{}.aggregate($this + $total)').to_a
  end

  def test_aggregate_with_empty_collection
    # empty collection should return the init value
    assert_equal [42], FHIRPath.evaluate({}, '{}.aggregate($this + $total, 42)').to_a
    assert_equal ['hello'], FHIRPath.evaluate({}, '{}.aggregate($this + $total, "hello")').to_a
  end

  def test_aggregate_does_not_mutate_input
    resource = { 'items' => [1, 2, 3] }
    original = resource['items'].dup
    FHIRPath.evaluate(resource, 'items.aggregate($this + $total, 0)')
    assert_equal original, resource['items']
  end

  def test_aggregate_nested_collections
    resource = { 'groups' => [[1, 2], [3, 4, 5]] }
    # sum of all numbers: 1+2+3+4+5 = 15
    assert_equal [15], FHIRPath.evaluate(resource, 'groups.aggregate($this + $total, 0)').to_a
  end
end
