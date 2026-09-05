# frozen_string_literal: true

require 'test_helper'

class FHIRPathLastFunctionTest < Minitest::Test
  def test_last_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.last()')
  end

  def test_last_on_singleton_returns_that_item
    assert_equal [1], FHIRPath.evaluate({}, '1.last()').to_a
    assert_equal ['a'], FHIRPath.evaluate({}, "'a'.last()").to_a
  end

  def test_last_on_multiple_items_returns_last_item
    assert_equal [3], FHIRPath.evaluate({}, '(1 | 2 | 3).last()').to_a
    assert_equal ['c'], FHIRPath.evaluate({}, "('a' | 'b' | 'c').last()").to_a
  end

  def test_last_on_this_focus
    assert_equal [3], FHIRPath.evaluate({}, '(1 | 2 | 3).select($this).last()').to_a
    assert_equal [2], FHIRPath.evaluate({}, '(1 | 2).where($this > 0).last()').to_a
  end

  def test_last_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [3], FHIRPath.evaluate(resource, 'g.last()').to_a
  end

  def test_last_requires_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).last(\'x\')')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_last_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.last()')
    assert_equal [1, 2, 3], resource['g']
  end
end
