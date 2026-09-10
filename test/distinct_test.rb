# frozen_string_literal: true

require 'test_helper'

class FHIRPathDistinctTest < Minitest::Test
  def test_distinct_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.distinct()')
  end

  def test_distinct_on_singleton_returns_singleton
    assert_equal [1], FHIRPath.evaluate({}, '1.distinct()').to_a
  end

  def test_distinct_removes_duplicate_integers
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 1 | 2 | 3 | 1).distinct()').to_a
  end

  def test_distinct_removes_duplicate_strings
    assert_equal %w[a b c], FHIRPath.evaluate({}, "('a' | 'b' | 'a' | 'c').distinct()").to_a
  end

  def test_distinct_preserves_first_occurrence_order
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 1 | 3).distinct()').to_a
  end

  def test_distinct_on_boolean_values
    assert_equal [true, false], FHIRPath.evaluate({}, '(true | false | true).distinct()').to_a
  end

  def test_distinct_on_mixed_types
    assert_equal [1, 'a', true], FHIRPath.evaluate({}, "(1 | 'a' | true | 1).distinct()").to_a
  end

  def test_distinct_on_numbers_with_decimals
    assert_equal [1, 1.5, 2], FHIRPath.evaluate({}, '(1 | 1.5 | 1 | 2).distinct()').to_a
  end

  def test_distinct_on_this_focus
    assert_equal [1, 2], FHIRPath.evaluate({}, '(1 | 1 | 2).select($this).distinct()').to_a
  end

  def test_distinct_does_not_mutate_input
    resource = { 'g' => [1, 2, 1, 3] }
    FHIRPath.evaluate(resource, 'g.distinct()')
    assert_equal [1, 2, 1, 3], resource['g']
  end
end
