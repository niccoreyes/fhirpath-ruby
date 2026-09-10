# frozen_string_literal: true

require 'test_helper'

class FHIRPathRepeatTest < Minitest::Test
  def test_repeat_on_empty_collection_returns_empty
    assert_empty FHIRPath.evaluate({}, '{}.repeat(2)')
  end

  def test_repeat_with_zero_count_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(0)')
  end

  def test_repeat_with_negative_count_returns_empty
    assert_empty FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(-1)')
  end

  def test_repeat_with_non_integer_count_raises_error
    error = assert_raises(FHIRPath::TypeError) do
      FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(1.5)')
    end
    assert_equal :expected_integer, error.code
  end

  def test_repeat_once_returns_original_collection
    assert_equal [1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(1)').to_a
  end

  def test_repeat_twice_returns_collection_twice
    assert_equal [1, 2, 3, 1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(2)').to_a
  end

  def test_repeat_three_times_returns_collection_three_times
    assert_equal [1, 2, 3, 1, 2, 3, 1, 2, 3], FHIRPath.evaluate({}, '(1 | 2 | 3).repeat(3)').to_a
  end

  def test_repeat_on_singleton
    assert_equal [1, 1, 1], FHIRPath.evaluate({}, '1.repeat(3)').to_a
  end

  def test_repeat_on_string_values
    assert_equal %w[a b a b], FHIRPath.evaluate({}, "('a' | 'b').repeat(2)").to_a
  end

  def test_repeat_on_boolean_values
    assert_equal [true, false, true, false], FHIRPath.evaluate({}, '(true | false).repeat(2)').to_a
  end

  def test_repeat_does_not_mutate_input
    resource = { 'g' => [1, 2] }
    FHIRPath.evaluate(resource, 'g.repeat(2)')
    assert_equal [1, 2], resource['g']
  end
end
