# frozen_string_literal: true

require 'test_helper'

class FHIRPathSubsettingFunctionsTest < Minitest::Test
  # --- tail() ---

  def test_tail_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.tail()')
  end

  def test_tail_on_singleton_returns_empty
    assert_empty FHIRPath.evaluate({}, '1.tail()')
  end

  def test_tail_on_multiple_items_returns_all_but_first
    assert_equal [2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).tail()').to_a
    assert_equal %w[b c], FHIRPath.evaluate({}, "('a' | 'b' | 'c').tail()").to_a
  end

  def test_tail_on_this_focus
    assert_equal [2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).select($this).tail()').to_a
    assert_equal [2], FHIRPath.evaluate({}, '(1 | 2).where($this > 0).tail()').to_a
  end

  def test_tail_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [2, 3], FHIRPath.evaluate(resource, 'g.tail()').to_a
  end

  def test_tail_requires_zero_arguments
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).tail(1)')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_tail_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.tail()')
    assert_equal [1, 2, 3], resource['g']
  end

  # --- take(n) ---

  def test_take_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.take(2)')
  end

  def test_take_with_zero_or_negative_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).take(0)')
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).take(-1)')
  end

  def test_take_with_n_less_than_size_returns_first_n
    assert_equal [1, 2], FHIRPath.evaluate({}, '(1 | 2 | 3).take(2)').to_a
    assert_equal ['a'], FHIRPath.evaluate({}, "('a' | 'b' | 'c').take(1)").to_a
  end

  def test_take_with_n_at_or_above_size_returns_full_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).take(3)').to_a
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).take(4)').to_a
  end

  def test_take_with_huge_n_returns_full_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).take(1000000000000000000000000000000)').to_a
  end

  def test_take_on_single_item
    assert_equal [1], FHIRPath.evaluate({}, '1.take(1)').to_a
    assert_empty FHIRPath.evaluate({}, '1.take(0)')
  end

  def test_take_on_this_focus
    assert_equal [1, 2], FHIRPath.evaluate({}, '(1 | 2 | 3).select($this).take(2)').to_a
  end

  def test_take_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [1, 2], FHIRPath.evaluate(resource, 'g.take(2)').to_a
  end

  def test_take_requires_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).take()')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_take_rejects_non_integer_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).take(1.5)')
    end
    assert_equal :expected_integer, error.code
  end

  def test_take_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.take(2)')
    assert_equal [1, 2, 3], resource['g']
  end

  # --- skip(n) ---

  def test_skip_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.skip(2)')
  end

  def test_skip_with_zero_or_negative_returns_full_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).skip(0)').to_a
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).skip(-1)').to_a
  end

  def test_skip_with_n_at_or_above_size_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).skip(3)')
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).skip(4)')
  end

  def test_skip_with_huge_n_returns_empty_collection
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).skip(1000000000000000000000000000000)')
  end

  def test_skip_with_n_less_than_size_returns_items_after_skipping
    assert_equal [2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).skip(1)').to_a
    assert_equal %w[b c], FHIRPath.evaluate({}, "('a' | 'b' | 'c').skip(1)").to_a
  end

  def test_skip_on_single_item
    assert_empty FHIRPath.evaluate({}, '1.skip(1)')
    assert_equal [1], FHIRPath.evaluate({}, '1.skip(0)').to_a
  end

  def test_skip_on_this_focus
    assert_equal [3], FHIRPath.evaluate({}, '(1 | 2 | 3).select($this).skip(2)').to_a
  end

  def test_skip_on_navigation_result
    resource = { 'g' => [1, 2, 3] }
    assert_equal [2, 3], FHIRPath.evaluate(resource, 'g.skip(1)').to_a
  end

  def test_skip_requires_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).skip()')
    end
    assert_equal :invalid_arity, error.code
  end

  def test_skip_rejects_non_integer_argument
    error = assert_raises(FHIRPath::EvaluationError) do
      FHIRPath.evaluate({}, '(1 | 2).skip(1.5)')
    end
    assert_equal :expected_integer, error.code
  end

  def test_skip_does_not_mutate_input
    resource = { 'g' => [1, 2, 3] }
    FHIRPath.evaluate(resource, 'g.skip(1)')
    assert_equal [1, 2, 3], resource['g']
  end
end
