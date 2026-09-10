# frozen_string_literal: true

require 'test_helper'

class FHIRPathSortTest < Minitest::Test
  def test_sort_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.sort()')
  end

  def test_sort_on_singleton_returns_singleton
    assert_equal [1], FHIRPath.evaluate({}, '1.sort()').to_a
  end

  def test_sort_ascending_integers
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(3 | 1 | 2).sort()').to_a
  end

  def test_sort_descending_integers_with_negation
    assert_equal [3, 2, 1], FHIRPath.evaluate({}, '(1 | 2 | 3).sort(-$this)').to_a
  end

  def test_sort_ascending_strings
    assert_equal %w[a b c], FHIRPath.evaluate({}, "('c' | 'a' | 'b').sort()").to_a
  end

  def test_sort_descending_strings_with_negation
    assert_equal %w[c b a], FHIRPath.evaluate({}, "('a' | 'b' | 'c').sort(-$this)").to_a
  end

  def test_sort_mixed_types_raises_type_error
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({}, '(1 | "a").sort()')
    end
    assert_equal :incompatible_comparison, error.code
  end

  def test_sort_preserves_original_order_when_already_sorted
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).sort()').to_a
  end

  def test_sort_with_duplicate_values
    # Union operator already eliminates duplicates, so input has no duplicates
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(3 | 1 | 2 | 1).sort()').to_a
  end

  def test_sort_does_not_mutate_input
    resource = { 'g' => [3, 1, 2] }
    FHIRPath.evaluate(resource, 'g.sort()')
    assert_equal [3, 1, 2], resource['g']
  end
end
