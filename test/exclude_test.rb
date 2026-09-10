# frozen_string_literal: true

require 'test_helper'

class FHIRPathExcludeTest < Minitest::Test
  def test_exclude_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.exclude(1 | 2)')
  end

  def test_exclude_with_empty_argument_returns_original_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).exclude({})').to_a
  end

  def test_exclude_no_matching_elements_returns_original_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).exclude(4 | 5)').to_a
  end

  def test_exclude_single_matching_element
    assert_equal [1, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).exclude(2)').to_a
  end

  def test_exclude_multiple_matching_elements
    assert_equal [1], FHIRPath.evaluate({}, '(1 | 2 | 3).exclude(2 | 3)').to_a
  end

  def test_exclude_removes_all_occurrences
    assert_equal [1, 3], FHIRPath.evaluate({}, '(1 | 2 | 2 | 3).exclude(2)').to_a
  end

  def test_exclude_preserves_order_of_remaining_elements
    assert_equal [3, 1], FHIRPath.evaluate({}, '(3 | 1 | 2).exclude(2)').to_a
  end

  def test_exclude_on_string_values
    assert_equal %w[a c], FHIRPath.evaluate({}, "('a' | 'b' | 'c').exclude('b')").to_a
  end

  def test_exclude_on_boolean_values
    assert_equal [false], FHIRPath.evaluate({}, '(true | false).exclude(true)').to_a
  end

  def test_exclude_on_mixed_types
    assert_equal [1, true], FHIRPath.evaluate({}, "(1 | 'a' | true).exclude('a')").to_a
  end

  def test_exclude_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.exclude(2)')
    assert_equal [1, 2, 3], resource['g']
  end
end
