# frozen_string_literal: true

require 'test_helper'

class FHIRPathIntersectTest < Minitest::Test
  def test_intersect_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.intersect(1 | 2)')
  end

  def test_intersect_with_empty_argument_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2).intersect({})')
  end

  def test_intersect_no_common_elements_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2).intersect(3 | 4)')
  end

  def test_intersect_single_common_element
    assert_equal [2], FHIRPath.evaluate({}, '(1 | 2 | 3).intersect(2 | 4)').to_a
  end

  def test_intersect_multiple_common_elements
    assert_equal [2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).intersect(2 | 3 | 4)').to_a
  end

  def test_intersect_preserves_first_occurrence_order_from_first_collection
    assert_equal [3, 1, 2], FHIRPath.evaluate({}, '(3 | 1 | 2).intersect(1 | 2 | 3)').to_a
  end

  def test_intersect_removes_duplicates_from_result
    assert_equal [2], FHIRPath.evaluate({}, '(2 | 2 | 3).intersect(2 | 2 | 4)').to_a
  end

  def test_intersect_on_string_values
    assert_equal ['b'], FHIRPath.evaluate({}, "('a' | 'b' | 'c').intersect('b' | 'd')").to_a
  end

  def test_intersect_on_boolean_values
    assert_equal [true], FHIRPath.evaluate({}, '(true | false).intersect(true)').to_a
  end

  def test_intersect_on_mixed_types
    assert_equal [1, 'a'], FHIRPath.evaluate({}, "(1 | 'a' | true).intersect(1 | 'a' | false)").to_a
  end

  def test_intersect_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.intersect(2 | 3 | 4)')
    assert_equal [1, 2, 3], resource['g']
  end
end
